const { test } = require('node:test');
const assert = require('node:assert/strict');
const validate = require('./reuse-validation.cjs');

function fixture(options = {}) {
  const pr = {
    number: 42, merged_at: '2026-11-02', merge_commit_sha: 'merged',
    base: { ref: 'master', repo: { full_name: 'owner/repo' } },
    head: { sha: 'pr-head' },
  };
  const run = {
    id: 123, status: 'completed', conclusion: 'success', run_attempt: 2,
    head_branch: 'master', pull_requests: [{ number: 42 }],
    html_url: 'https://github.com/owner/repo/actions/runs/123',
    ...options.run,
  };
  const calls = [];
  let time = 0;
  const rest = {
    repos: { listPullRequestsAssociatedWithCommit() {} },
    actions: {
      listWorkflowRuns() {}, listWorkflowRunArtifacts() {},
      async getWorkflowRun(args) {
        calls.push(['poll', args]);
        return { data: { ...run, status: 'completed', ...options.completed } };
      },
    },
  };
  const args = {
    github: {
      rest,
      async paginate(method, params) {
        if (method === rest.repos.listPullRequestsAssociatedWithCommit) {
          calls.push(['pulls', params]);
          return options.pulls ?? [pr];
        }
        if (method === rest.actions.listWorkflowRuns) {
          calls.push(['runs', params]);
          if (options.apiError) throw new Error('API unavailable');
          return options.runs ?? [run];
        }
        if (method === rest.actions.listWorkflowRunArtifacts) {
          calls.push(['artifacts', params]);
          if (options.artifactError) throw new Error('Artifact API unavailable');
          return options.artifacts ?? [{
            name: 'lua-validation-tree-attempt-2', expired: false,
          }];
        }
        assert.fail('Unexpected API call');
      },
    },
    context: {
      repo: { owner: 'owner', repo: 'repo' }, runId: 999,
      eventName: 'push', ref: 'refs/heads/master', ...options.context,
    },
    core: { info() {}, warning(message) { calls.push(['warning', message]); } },
    commit: 'merged', tree: 'tree',
    sleep: async ms => { time += ms; }, now: () => time,
    waitMs: options.waitMs ?? 60_000,
  };
  return { calls, args, resolve: () => validate(args) };
}

test('PRs always test without consulting prior runs', async () => {
  const f = fixture({ context: { eventName: 'pull_request' } });
  assert.equal((await f.resolve()).decision, 'test');
  assert.deepEqual(f.calls, []);
});

test('master reuses the passing PR merge tree and explains the skip', async () => {
  const f = fixture();
  const result = await f.resolve();
  assert.equal(result.decision, 'reuse');
  assert.match(result.reason, /PR #42 CI passed.*exactly matches tree/);
  assert.match(result.reason, /https:\/\/github.com\/owner\/repo\/actions\/runs\/123/);
  assert.match(result.reason, /attempt 2/);
  const query = f.calls.find(([type]) => type === 'runs')[1];
  assert.equal(query.head_sha, 'pr-head');
  assert.equal(query.event, 'pull_request');
  assert.equal(query.workflow_id, 'Test.yml');
});

test('fork PR metadata may omit the PR association', async () => {
  assert.equal((await fixture({ run: { pull_requests: [] } }).resolve()).decision, 'reuse');
});

test('a different PR association is not reused', async () => {
  assert.equal((await fixture({ run: { pull_requests: [{ number: 7 }] } }).resolve()).decision, 'test');
});

test('direct master pushes and intermediate commits in a push test', async () => {
  assert.equal((await fixture({ pulls: [] }).resolve()).decision, 'test');
  const f = fixture();
  f.args.commit = 'intermediate';
  assert.equal((await f.resolve()).decision, 'test');
});

for (const [name, artifacts] of [
  ['missing', []],
  ['different tree', [{ name: 'lua-validation-other-tree-attempt-2' }]],
  ['previous attempt', [{ name: 'lua-validation-tree-attempt-1' }]],
  ['expired', [{ name: 'lua-validation-tree-attempt-2', expired: true }]],
]) {
  test(`${name} proof falls back to tests`, async () => {
    const result = await fixture({ artifacts }).resolve();
    assert.equal(result.decision, 'test');
    assert.match(result.reason, /no unexpired validation artifact matching Git tree tree/);
  });
}

test('tags reuse master CI for the peeled, checked-out commit', async () => {
  const f = fixture({ context: { ref: 'refs/tags/v1.0.0' } });
  const result = await f.resolve();
  assert.equal(result.decision, 'reuse');
  assert.match(result.reason, /master CI for tagged commit merged passed/);
  assert.equal(f.calls.some(([type]) => type === 'pulls'), false);
  const query = f.calls.find(([type]) => type === 'runs')[1];
  assert.equal(query.head_sha, 'merged');
  assert.equal(query.event, 'push');
});

test('tags do not reuse push runs from another branch', async () => {
  const f = fixture({ context: { ref: 'refs/tags/v1' }, run: { head_branch: 'feature' } });
  assert.equal((await f.resolve()).decision, 'test');
});

test('missing CI runs fall back at both merge and tag stages', async () => {
  for (const ref of ['refs/heads/master', 'refs/tags/v1']) {
    assert.equal((await fixture({ context: { ref }, runs: [] }).resolve()).decision, 'test');
  }
});

test('in-progress validation is awaited instead of starting duplicate tests', async () => {
  const f = fixture({ run: { status: 'in_progress', conclusion: null }, completed: { conclusion: 'success' } });
  assert.equal((await f.resolve()).decision, 'reuse');
  assert.equal(f.calls.filter(([type]) => type === 'poll').length, 1);
});

test('waiting has a bounded fallback', async () => {
  const f = fixture({ run: { status: 'queued' }, waitMs: 0 });
  assert.equal((await f.resolve()).decision, 'test');
});

for (const conclusion of ['failure', 'timed_out', 'action_required']) {
  test(`${conclusion} for the same source blocks merge and release`, async () => {
    for (const ref of ['refs/heads/master', 'refs/tags/v1']) {
      assert.equal((await fixture({ context: { ref }, run: { conclusion } }).resolve()).decision, 'block');
    }
  });
}

test('failed master validation blocks tags even if artifact lookup would fail', async () => {
  const f = fixture({ context: { ref: 'refs/tags/v1' }, run: { conclusion: 'failure' }, artifactError: true });
  assert.equal((await f.resolve()).decision, 'block');
  assert.equal(f.calls.some(([type]) => type === 'artifacts'), false);
});

test('a failed PR run for different files requires fresh tests', async () => {
  assert.equal((await fixture({ run: { conclusion: 'failure' }, artifacts: [] }).resolve()).decision, 'test');
});

test('latest matching run takes precedence over an older pass', async () => {
  const f = fixture({ runs: [
    { id: 1, head_branch: 'master', status: 'completed', conclusion: 'success' },
    { id: 2, head_branch: 'master', status: 'completed', conclusion: 'failure' },
  ], context: { ref: 'refs/tags/v1' } });
  assert.equal((await f.resolve()).decision, 'block');
});

test('cancelled or skipped runs fall back to tests', async () => {
  for (const conclusion of ['cancelled', 'skipped', 'neutral', 'stale']) {
    assert.equal((await fixture({ run: { conclusion } }).resolve()).decision, 'test');
  }
});

test('API failures trigger full tests, never an unverified pass', async () => {
  for (const options of [{ apiError: true }, { artifactError: true }]) {
    const f = fixture(options);
    assert.equal((await f.resolve()).decision, 'test');
    assert.equal(f.calls.some(([type]) => type === 'warning'), true);
  }
});
