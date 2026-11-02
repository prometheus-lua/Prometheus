// A matching artifact identifies the checked-out Git tree, not a passing test.
// Only the latest attempt of a successful Test.yml run can supply a pass.
module.exports = async function reuseValidation({ github, context, core,
  commit = process.env.VALIDATION_COMMIT,
  tree = process.env.VALIDATION_TREE,
  sleep = ms => new Promise(resolve => setTimeout(resolve, ms)),
  now = Date.now,
  waitMs = 70 * 60 * 1000,
}) {
  const result = (decision, reason) => ({ decision, reason });
  if (context.eventName === 'pull_request') {
    return result('test', 'Pull requests always run the full Lua suite.');
  }
  const repo = context.repo;
  const isTag = context.ref.startsWith('refs/tags/');
  try {
    let head;
    let pr;
    if (isTag) {
      head = commit;
    } else if (context.ref === 'refs/heads/master') {
      const pulls = await github.paginate(github.rest.repos.listPullRequestsAssociatedWithCommit,
        { ...repo, commit_sha: commit, per_page: 100 });
      pr = pulls.find(p => p.merged_at && p.base.ref === 'master' &&
        p.base.repo.full_name === `${repo.owner}/${repo.repo}` && p.merge_commit_sha === commit);
      if (!pr) return result('test', 'No merged PR found for this master commit; running the full suite.');
      head = pr.head.sha;
    } else {
      return result('test', 'No reusable validation source for this event; running the full suite.');
    }

    const runs = await github.paginate(github.rest.actions.listWorkflowRuns, {
      ...repo, workflow_id: 'Test.yml', head_sha: head,
      event: isTag ? 'push' : 'pull_request', per_page: 100,
    });
    // Do not select only successful runs: that could hide a newer failure.
    let run = runs.filter(r => r.id !== context.runId &&
      (isTag ? r.head_branch === 'master' :
        // GitHub can omit pull_requests for fork runs. The head SHA and
        // matching tested tree still identify the source in that case.
        !r.pull_requests?.length || r.pull_requests.some(p => p.number === pr.number)))
      .sort((a, b) => b.id - a.id)[0];
    if (!run) return result('test', 'No matching CI run found; running the full suite.');

    const deadline = now() + waitMs;
    while (run.status !== 'completed') {
      if (now() >= deadline) {
        return result('test', `CI run ${run.html_url} did not finish within 70 minutes; running the full suite.`);
      }
      core.info(`Waiting for ${run.html_url} (${run.status}).`);
      await sleep(30_000);
      ({ data: run } = await github.rest.actions.getWorkflowRun({ ...repo, run_id: run.id }));
    }

    const failed = ['failure', 'timed_out', 'action_required'].includes(run.conclusion);
    if (isTag && failed) {
      return result('block', `Validation failed for this commit: ${run.html_url}. Fix or rerun that CI run before proceeding.`);
    }
    const artifacts = await github.paginate(github.rest.actions.listWorkflowRunArtifacts,
      { ...repo, run_id: run.id, per_page: 100 });
    const proof = artifacts.some(a => !a.expired &&
      a.name === `lua-validation-${tree}-attempt-${run.run_attempt}`);
    // A master run is already tied to this exact commit. A PR run needs a
    // matching tree artifact because head_sha identifies its branch head,
    // whereas checkout tests GitHub's temporary merge commit.
    if (proof && failed) {
      return result('block', `Validation failed for this source: ${run.html_url}. Fix or rerun that CI run before proceeding.`);
    }
    if (run.conclusion === 'success' && proof) {
      const source = isTag ? `master CI for tagged commit ${commit}` : `PR #${pr.number} CI`;
      return result('reuse', `${source} passed, and its recorded Git tree exactly matches ${tree}. Reusing run ${run.html_url} (attempt ${run.run_attempt}).`);
    }
    if (!proof) {
      return result('test', `CI run ${run.html_url} (attempt ${run.run_attempt}) has no unexpired validation artifact matching Git tree ${tree}; running the full suite.`);
    }
    return result('test', `CI run ${run.html_url} concluded ${run.conclusion}; running the full suite.`);
  } catch (error) {
    core.warning(`Could not verify prior validation: ${error.message}`);
    return result('test', `Prior validation could not be verified (${error.message}); running the full suite.`);
  }
};
