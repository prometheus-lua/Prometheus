const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const crypto = require('crypto');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(bodyParser.json({ limit: '50mb' }));
app.use(bodyParser.urlencoded({ extended: true, limit: '50mb' }));

// Homepage dengan UI Advanced
app.get('/', (req, res) => {
    res.send(`
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Prometheus Advanced Obfuscator</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #0a0a0f 0%, #1a1a2e 50%, #0f0f1a 100%);
            min-height: 100vh;
            padding: 20px;
            color: #fff;
        }
        .container { max-width: 1500px; margin: 0 auto; }
        h1 {
            text-align: center;
            margin-bottom: 8px;
            font-size: 2.8em;
            background: linear-gradient(90deg, #ff0080, #00d4ff, #00ff88, #ff0080);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-size: 300% auto;
            animation: gradient 4s linear infinite;
        }
        @keyframes gradient {
            0% { background-position: 0% center; }
            100% { background-position: 300% center; }
        }
        .subtitle { text-align: center; color: #666; margin-bottom: 25px; font-size: 1em; }
        .subtitle span { color: #00d4ff; font-weight: bold; }
        .editor-container { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin-bottom: 20px; }
        @media (max-width: 1000px) { .editor-container { grid-template-columns: 1fr; } }
        .editor-box {
            background: rgba(255, 255, 255, 0.02);
            border-radius: 16px;
            padding: 20px;
            border: 1px solid rgba(255, 255, 255, 0.08);
        }
        .editor-box h3 { margin-bottom: 12px; color: #00d4ff; font-size: 1.1em; display: flex; align-items: center; gap: 8px; }
        textarea {
            width: 100%;
            height: 400px;
            background: #08080f;
            border: 2px solid #1a1a2f;
            border-radius: 12px;
            padding: 15px;
            color: #a0e0a0;
            font-family: 'Fira Code', 'JetBrains Mono', 'Consolas', monospace;
            font-size: 13px;
            resize: vertical;
            line-height: 1.5;
        }
        textarea:focus { outline: none; border-color: #00d4ff; box-shadow: 0 0 20px rgba(0, 212, 255, 0.15); }
        textarea::placeholder { color: #3a3a5a; }
        .btn-container { display: flex; justify-content: center; gap: 12px; flex-wrap: wrap; margin: 20px 0; }
        button {
            padding: 14px 35px;
            font-size: 14px;
            font-weight: 700;
            border: none;
            border-radius: 50px;
            cursor: pointer;
            transition: all 0.3s ease;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        .btn-obfuscate { background: linear-gradient(135deg, #ff0080 0%, #7928ca 100%); color: #fff; }
        .btn-obfuscate:hover { transform: translateY(-2px); box-shadow: 0 15px 40px rgba(255, 0, 128, 0.3); }
        .btn-copy { background: linear-gradient(135deg, #00ff88 0%, #00b865 100%); color: #000; }
        .btn-copy:hover { transform: translateY(-2px); box-shadow: 0 15px 40px rgba(0, 255, 136, 0.3); }
        .btn-download { background: linear-gradient(135deg, #00d4ff 0%, #0099cc 100%); color: #000; }
        .btn-download:hover { transform: translateY(-2px); box-shadow: 0 15px 40px rgba(0, 212, 255, 0.3); }
        .btn-clear { background: linear-gradient(135deg, #ff4757 0%, #cc3344 100%); color: #fff; }
        .btn-clear:hover { transform: translateY(-2px); box-shadow: 0 15px 40px rgba(255, 71, 87, 0.3); }
        .status { text-align: center; padding: 15px; border-radius: 12px; margin: 15px auto; max-width: 700px; font-weight: 600; display: none; }
        .status.success { display: block; background: rgba(0, 255, 136, 0.1); border: 1px solid #00ff88; color: #00ff88; }
        .status.error { display: block; background: rgba(255, 71, 87, 0.1); border: 1px solid #ff4757; color: #ff4757; }
        .status.loading { display: block; background: rgba(0, 212, 255, 0.1); border: 1px solid #00d4ff; color: #00d4ff; }
        .settings {
            background: rgba(255, 255, 255, 0.02);
            border-radius: 16px;
            padding: 20px;
            margin-bottom: 20px;
            border: 1px solid rgba(255, 255, 255, 0.08);
        }
        .settings h3 { margin-bottom: 15px; color: #ff0080; display: flex; align-items: center; gap: 8px; }
        .settings-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 10px; }
        .setting-item {
            display: flex; align-items: center; gap: 10px;
            padding: 10px 12px; background: rgba(0, 0, 0, 0.3); border-radius: 8px;
            transition: all 0.2s ease; cursor: pointer;
        }
        .setting-item:hover { background: rgba(255, 0, 128, 0.1); }
        .setting-item input[type="checkbox"] { width: 18px; height: 18px; accent-color: #ff0080; cursor: pointer; }
        .setting-item label { cursor: pointer; font-size: 13px; color: #ccc; }
        .setting-item.active label { color: #fff; }
        .level-selector { margin-top: 15px; padding-top: 15px; border-top: 1px solid rgba(255,255,255,0.1); }
        .level-selector h4 { margin-bottom: 10px; color: #00d4ff; font-size: 14px; }
        .level-buttons { display: flex; gap: 10px; flex-wrap: wrap; }
        .level-btn {
            padding: 8px 20px; border: 2px solid #333; background: transparent;
            color: #888; border-radius: 20px; cursor: pointer; font-size: 12px;
            transition: all 0.2s ease;
        }
        .level-btn:hover { border-color: #ff0080; color: #ff0080; }
        .level-btn.active { border-color: #ff0080; background: #ff0080; color: #fff; }
        .stats { display: flex; justify-content: center; gap: 20px; margin: 15px 0; flex-wrap: wrap; }
        .stat-item { background: rgba(255,255,255,0.03); padding: 12px 20px; border-radius: 12px; text-align: center; min-width: 120px; }
        .stat-value { font-size: 1.5em; font-weight: 700; color: #00d4ff; }
        .stat-label { font-size: 0.8em; color: #666; margin-top: 3px; }
        footer { text-align: center; margin-top: 30px; padding: 15px; color: #444; font-size: 12px; }
        .features { display: flex; justify-content: center; gap: 15px; flex-wrap: wrap; margin: 10px 0; }
        .feature-tag { background: rgba(255,0,128,0.1); border: 1px solid rgba(255,0,128,0.3); padding: 5px 12px; border-radius: 20px; font-size: 11px; color: #ff0080; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔐 Prometheus Advanced</h1>
        <p class="subtitle">Enterprise-Grade Lua Obfuscator • <span>Luraph-Style Protection</span></p>
        
        <div class="features">
            <span class="feature-tag">🔄 Control Flow</span>
            <span class="feature-tag">🔐 String Encryption</span>
            <span class="feature-tag">🎭 VM Wrapper</span>
            <span class="feature-tag">🛡️ Anti-Debug</span>
            <span class="feature-tag">💀 Dead Code</span>
            <span class="feature-tag">🔢 Constant Folding</span>
        </div>
        
        <div class="settings">
            <h3>⚙️ Protection Settings</h3>
            <div class="settings-grid">
                <div class="setting-item active"><input type="checkbox" id="strEncrypt" checked><label for="strEncrypt">🔐 String Encryption</label></div>
                <div class="setting-item active"><input type="checkbox" id="varMangle" checked><label for="varMangle">🔤 Variable Mangling</label></div>
                <div class="setting-item active"><input type="checkbox" id="controlFlow" checked><label for="controlFlow">🔄 Control Flow</label></div>
                <div class="setting-item active"><input type="checkbox" id="deadCode" checked><label for="deadCode">💀 Dead Code Injection</label></div>
                <div class="setting-item active"><input type="checkbox" id="constFold" checked><label for="constFold">🔢 Constant Folding</label></div>
                <div class="setting-item active"><input type="checkbox" id="vmWrapper" checked><label for="vmWrapper">🎭 VM Wrapper</label></div>
                <div class="setting-item active"><input type="checkbox" id="antiDebug" checked><label for="antiDebug">🛡️ Anti-Debug</label></div>
                <div class="setting-item active"><input type="checkbox" id="envWrapper" checked><label for="envWrapper">🌍 Environment Wrap</label></div>
                <div class="setting-item"><input type="checkbox" id="antiTamper"><label for="antiTamper">⚠️ Anti-Tamper</label></div>
                <div class="setting-item"><input type="checkbox" id="watermark"><label for="watermark">💧 Add Watermark</label></div>
            </div>
            <div class="level-selector">
                <h4>🎚️ Obfuscation Level</h4>
                <div class="level-buttons">
                    <button class="level-btn" data-level="1">Light</button>
                    <button class="level-btn" data-level="2">Medium</button>
                    <button class="level-btn active" data-level="3">Strong</button>
                    <button class="level-btn" data-level="4">Maximum</button>
                    <button class="level-btn" data-level="5">Paranoid</button>
                </div>
            </div>
        </div>
        
        <div class="stats">
            <div class="stat-item"><div class="stat-value" id="inputSize">0</div><div class="stat-label">Input (bytes)</div></div>
            <div class="stat-item"><div class="stat-value" id="outputSize">0</div><div class="stat-label">Output (bytes)</div></div>
            <div class="stat-item"><div class="stat-value" id="ratio">0x</div><div class="stat-label">Size Ratio</div></div>
            <div class="stat-item"><div class="stat-value" id="strCount">0</div><div class="stat-label">Strings Encrypted</div></div>
        </div>
        
        <div class="editor-container">
            <div class="editor-box">
                <h3>📝 Input Script</h3>
                <textarea id="input" placeholder="-- Paste your Lua script here...

print('Hello World!')

local function example()
    local message = 'This is a test'
    print(message)
    return true
end

example()"></textarea>
            </div>
            <div class="editor-box">
                <h3>🔐 Protected Output</h3>
                <textarea id="output" placeholder="-- Protected script will appear here..." readonly></textarea>
            </div>
        </div>
        
        <div class="btn-container">
            <button class="btn-obfuscate" onclick="obfuscate()">🔐 Protect Script</button>
            <button class="btn-copy" onclick="copyOutput()">📋 Copy</button>
            <button class="btn-download" onclick="downloadOutput()">💾 Download</button>
            <button class="btn-clear" onclick="clearAll()">🗑️ Clear</button>
        </div>
        
        <div id="status" class="status"></div>
        
        <footer>Prometheus Advanced Obfuscator • Luraph-Style Protection • Self-Hosted</footer>
    </div>

    <script>
        let currentLevel = 3;
        const inputEl = document.getElementById('input');
        const outputEl = document.getElementById('output');
        
        // Level buttons
        document.querySelectorAll('.level-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                document.querySelectorAll('.level-btn').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                currentLevel = parseInt(btn.dataset.level);
                updateSettingsByLevel(currentLevel);
            });
        });
        
        // Setting items toggle
        document.querySelectorAll('.setting-item input').forEach(input => {
            input.addEventListener('change', () => {
                input.closest('.setting-item').classList.toggle('active', input.checked);
            });
        });
        
        function updateSettingsByLevel(level) {
            const settings = {
                1: ['strEncrypt', 'varMangle'],
                2: ['strEncrypt', 'varMangle', 'deadCode', 'constFold'],
                3: ['strEncrypt', 'varMangle', 'controlFlow', 'deadCode', 'constFold', 'vmWrapper', 'antiDebug', 'envWrapper'],
                4: ['strEncrypt', 'varMangle', 'controlFlow', 'deadCode', 'constFold', 'vmWrapper', 'antiDebug', 'envWrapper', 'antiTamper'],
                5: ['strEncrypt', 'varMangle', 'controlFlow', 'deadCode', 'constFold', 'vmWrapper', 'antiDebug', 'envWrapper', 'antiTamper', 'watermark']
            };
            document.querySelectorAll('.setting-item input').forEach(input => {
                const checked = settings[level].includes(input.id);
                input.checked = checked;
                input.closest('.setting-item').classList.toggle('active', checked);
            });
        }
        
        inputEl.addEventListener('input', () => {
            document.getElementById('inputSize').textContent = inputEl.value.length;
        });
        
        function showStatus(message, type) {
            const status = document.getElementById('status');
            status.textContent = message;
            status.className = 'status ' + type;
        }

        async function obfuscate() {
            const input = inputEl.value;
            if (!input.trim()) { showStatus('❌ Please enter a script!', 'error'); return; }
            
            showStatus('⏳ Protecting script... Please wait...', 'loading');
            
            const settings = {
                level: currentLevel,
                strEncrypt: document.getElementById('strEncrypt').checked,
                varMangle: document.getElementById('varMangle').checked,
                controlFlow: document.getElementById('controlFlow').checked,
                deadCode: document.getElementById('deadCode').checked,
                constFold: document.getElementById('constFold').checked,
                vmWrapper: document.getElementById('vmWrapper').checked,
                antiDebug: document.getElementById('antiDebug').checked,
                envWrapper: document.getElementById('envWrapper').checked,
                antiTamper: document.getElementById('antiTamper').checked,
                watermark: document.getElementById('watermark').checked
            };
            
            try {
                const response = await fetch('/api/obfuscate', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ script: input, settings })
                });
                const data = await response.json();
                if (data.success) {
                    outputEl.value = data.result;
                    document.getElementById('outputSize').textContent = data.result.length;
                    document.getElementById('ratio').textContent = (data.result.length / input.length).toFixed(1) + 'x';
                    document.getElementById('strCount').textContent = data.stats?.stringsEncrypted || 0;
                    showStatus('✅ Protection complete! Output: ' + data.result.length + ' bytes', 'success');
                } else {
                    showStatus('❌ Error: ' + data.error, 'error');
                }
            } catch (error) {
                showStatus('❌ Network error: ' + error.message, 'error');
            }
        }

        function copyOutput() {
            if (!outputEl.value) { showStatus('❌ No output!', 'error'); return; }
            navigator.clipboard.writeText(outputEl.value).then(() => showStatus('✅ Copied!', 'success'));
        }

        function downloadOutput() {
            if (!outputEl.value) { showStatus('❌ No output!', 'error'); return; }
            const blob = new Blob([outputEl.value], { type: 'text/plain' });
            const a = document.createElement('a');
            a.href = URL.createObjectURL(blob);
            a.download = 'protected_' + Date.now() + '.lua';
            a.click();
            showStatus('✅ Downloaded!', 'success');
        }

        function clearAll() {
            inputEl.value = '';
            outputEl.value = '';
            ['inputSize', 'outputSize', 'strCount'].forEach(id => document.getElementById(id).textContent = '0');
            document.getElementById('ratio').textContent = '0x';
            document.getElementById('status').className = 'status';
        }
    </script>
</body>
</html>
    `);
});

// ==================== ADVANCED OBFUSCATOR ENGINE ====================

class LuaObfuscator {
    constructor(settings = {}) {
        this.settings = settings;
        this.level = settings.level || 3;
        this.stats = { stringsEncrypted: 0, varsRenamed: 0 };
        this.encryptionKey = this.generateKey(16);
        this.varCounter = 0;
        this.stringTable = [];
        this.reserved = new Set([
            'and','break','do','else','elseif','end','false','for','function','goto',
            'if','in','local','nil','not','or','repeat','return','then','true','until','while',
            'game','workspace','script','Instance','Vector3','CFrame','Vector2','Color3',
            'BrickColor','UDim2','UDim','Enum','Ray','Region3','Rect','math','string','table',
            'coroutine','os','debug','bit32','utf8','print','warn','error','assert','pcall',
            'xpcall','loadstring','require','spawn','delay','wait','task','tick','time','typeof',
            'type','tostring','tonumber','pairs','ipairs','next','select','unpack','pack',
            'setmetatable','getmetatable','rawget','rawset','rawequal','rawlen',
            'getfenv','setfenv','getgenv','getrenv','setreadonly','getrawmetatable',
            'hookfunction','hookmetamethod','newcclosure','islclosure','iscclosure',
            'checkcaller','getcallingscript','getnamecallmethod','setnamecallmethod',
            'firetouchinterest','fireproximityprompt','fireclickdetector',
            'getsenv','getmenv','getscriptclosure','getscripts','getrunningscripts',
            'getcustomasset','getsynasset','isrbxactive','setclipboard','setfflag',
            'Drawing','cleardrawcache','getrenderproperty','setrenderproperty','isrenderobj',
            '_G','shared','_VERSION','self'
        ]);
    }

    generateKey(length) {
        const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
        let result = '';
        for (let i = 0; i < length; i++) {
            result += chars.charAt(Math.floor(Math.random() * chars.length));
        }
        return result;
    }

    randomVar(prefix = '') {
        const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_';
        const allChars = chars + '0123456789';
        let length = 8 + Math.floor(Math.random() * 8);
        let result = prefix + chars[Math.floor(Math.random() * chars.length)];
        for (let i = 1; i < length; i++) {
            result += allChars[Math.floor(Math.random() * allChars.length)];
        }
        this.varCounter++;
        return result;
    }

    randomILVar() {
        // Generate IL-style variable like Luraph uses: IlIlIlIl
        const chars = ['I', 'l', '1'];
        let result = chars[Math.floor(Math.random() * 2)]; // Start with I or l
        let length = 10 + Math.floor(Math.random() * 10);
        for (let i = 1; i < length; i++) {
            result += chars[Math.floor(Math.random() * chars.length)];
        }
        return result;
    }

    randomInt(min = 1000, max = 99999) {
        return Math.floor(Math.random() * (max - min + 1)) + min;
    }

    randomHex(length = 8) {
        return '0x' + crypto.randomBytes(length / 2).toString('hex').toUpperCase();
    }

    // XOR encryption for strings
    xorEncrypt(str, key) {
        let result = [];
        for (let i = 0; i < str.length; i++) {
            result.push(str.charCodeAt(i) ^ key.charCodeAt(i % key.length));
        }
        return result;
    }

    // Generate string decryption function
    generateStringDecryptor() {
        const funcName = this.randomILVar();
        const keyVar = this.randomILVar();
        const dataVar = this.randomILVar();
        const resultVar = this.randomILVar();
        const indexVar = this.randomILVar();
        
        return {
            name: funcName,
            code: `local ${funcName}=(function(${dataVar},${keyVar})local ${resultVar}="";for ${indexVar}=1,#${dataVar} do ${resultVar}=${resultVar}..string.char(bit32.bxor(${dataVar}[${indexVar}],string.byte(${keyVar},(${indexVar}-1)%#${keyVar}+1)));end;return ${resultVar};end);`
        };
    }

    // Convert number to complex expression
    obfuscateNumber(num) {
        if (this.level < 2) return num.toString();
        
        const methods = [
            // Method 1: Addition
            () => {
                const a = Math.floor(Math.random() * num);
                const b = num - a;
                return `(${a}+${b})`;
            },
            // Method 2: Subtraction
            () => {
                const a = num + Math.floor(Math.random() * 1000);
                const b = a - num;
                return `(${a}-${b})`;
            },
            // Method 3: XOR
            () => {
                const a = Math.floor(Math.random() * 65535);
                const b = num ^ a;
                return `bit32.bxor(${a},${b})`;
            },
            // Method 4: Multiplication/Division
            () => {
                const divisors = [2, 4, 5, 8, 10, 16, 20, 25];
                for (const d of divisors) {
                    if (num % d === 0) {
                        return `(${num/d}*${d})`;
                    }
                }
                return num.toString();
            },
            // Method 5: Nested
            () => {
                const a = Math.floor(num / 2);
                const b = num - a;
                const c = Math.floor(Math.random() * 100);
                return `((${a}+${b})+${c}-${c})`;
            }
        ];
        
        const method = methods[Math.floor(Math.random() * methods.length)];
        return method();
    }

    // Encrypt string and add to table
    encryptString(str) {
        if (str.length === 0) return '""';
        if (str.length > 200) return null; // Skip very long strings
        
        this.stats.stringsEncrypted++;
        const encrypted = this.xorEncrypt(str, this.encryptionKey);
        
        return {
            data: `{${encrypted.join(',')}}`,
            key: `"${this.encryptionKey}"`
        };
    }

    // Generate junk code that looks real
    generateJunkCode(count = 5) {
        const junk = [];
        
        for (let i = 0; i < count; i++) {
            const type = Math.floor(Math.random() * 8);
            const v1 = this.randomILVar();
            const v2 = this.randomILVar();
            const v3 = this.randomILVar();
            const n1 = this.randomInt();
            const n2 = this.randomInt();
            
            switch (type) {
                case 0:
                    junk.push(`local ${v1}=${n1};`);
                    break;
                case 1:
                    junk.push(`local ${v1}=${n1};local ${v2}=${v1}+${n2};`);
                    break;
                case 2:
                    junk.push(`local ${v1}=function()return ${n1} end;`);
                    break;
                case 3:
                    junk.push(`local ${v1}={${n1},${n2}};`);
                    break;
                case 4:
                    junk.push(`local ${v1}=bit32.bxor(${n1},${n2});`);
                    break;
                case 5:
                    junk.push(`local ${v1}=(function()local ${v2}=${n1};return ${v2}+${n2} end)();`);
                    break;
                case 6:
                    junk.push(`local ${v1}=string.rep("",0);`);
                    break;
                case 7:
                    junk.push(`local ${v1},${v2}=${n1},${n2};local ${v3}=${v1}*${v2};`);
                    break;
            }
        }
        
        return junk.join('');
    }

    // Generate opaque predicates (always true/false but looks complex)
    generateOpaquePredicate(isTrue = true) {
        const v = this.randomILVar();
        const n1 = this.randomInt(1, 1000);
        const n2 = this.randomInt(1, 1000);
        
        const truePredicates = [
            `(${n1}*${n1}>=${n1})`,
            `(type("")=="string")`,
            `(${n1}==${n1})`,
            `(bit32.band(${n1},0)==0 or bit32.band(${n1},0)~=0)`,
            `((${n1}+${n2})-(${n2})==${n1})`,
            `(not not true)`,
            `(#""==0)`,
            `(math.abs(-${n1})==${n1})`
        ];
        
        const falsePredicates = [
            `(${n1}>${n1})`,
            `(type("")=="number")`,
            `(${n1}==${n1+1})`,
            `(#""~=0)`,
            `(nil)`,
            `(false)`,
            `(not true)`
        ];
        
        const predicates = isTrue ? truePredicates : falsePredicates;
        return predicates[Math.floor(Math.random() * predicates.length)];
    }

    // Generate anti-debug checks
    generateAntiDebug() {
        const checks = [];
        const errorVar = this.randomILVar();
        const checkVar = this.randomILVar();
        
        // Check for common debug tools
        checks.push(`
local ${checkVar}=(function()
local ${errorVar}=false;
pcall(function()
if getgenv then
local _g=getgenv();
if _g.SimpleSpy or _g.RemoteSpy or _g.HttpSpy or _g.Hydroxide or _g.Dex or _g.DarkDex then
${errorVar}=true;
end;
end;
end);
if ${errorVar} then return nil end;
return true;
end)();
if not ${checkVar} then return end;
`);
        
        return checks.join('');
    }

    // Generate environment wrapper
    generateEnvWrapper() {
        const envVar = this.randomILVar();
        const wrapperVar = this.randomILVar();
        
        return `local ${envVar}=setmetatable({},{__index=function(self,key)return rawget(self,key)or getfenv()[key]or _G[key]end,__newindex=function(self,key,value)rawset(self,key,value)end});setfenv(1,${envVar});`;
    }

    // Main obfuscation function
    obfuscate(script) {
        let result = script;
        const stringDecryptor = this.generateStringDecryptor();
        let needsDecryptor = false;
        
        // Step 1: String Encryption
        if (this.settings.strEncrypt !== false) {
            // Handle double-quoted strings
            result = result.replace(/"([^"\\]*(\\.[^"\\]*)*)"/g, (match, content) => {
                if (content.length === 0 || content.length > 150) return match;
                const encrypted = this.encryptString(content);
                if (encrypted) {
                    needsDecryptor = true;
                    return `${stringDecryptor.name}(${encrypted.data},${encrypted.key})`;
                }
                return match;
            });
            
            // Handle single-quoted strings
            result = result.replace(/'([^'\\]*(\\.[^'\\]*)*)'/g, (match, content) => {
                if (content.length === 0 || content.length > 150) return match;
                const encrypted = this.encryptString(content);
                if (encrypted) {
                    needsDecryptor = true;
                    return `${stringDecryptor.name}(${encrypted.data},${encrypted.key})`;
                }
                return match;
            });
        }
        
        // Step 2: Variable Mangling
        if (this.settings.varMangle !== false) {
            const varMap = new Map();
            const localPattern = /local\s+([a-zA-Z_][a-zA-Z0-9_]*)/g;
            let match;
            
            const tempScript = script;
            while ((match = localPattern.exec(tempScript)) !== null) {
                const varName = match[1];
                if (!varMap.has(varName) && !this.reserved.has(varName)) {
                    varMap.set(varName, this.randomILVar());
                    this.stats.varsRenamed++;
                }
            }
            
            varMap.forEach((newName, oldName) => {
                const regex = new RegExp(`\\b${oldName}\\b`, 'g');
                result = result.replace(regex, newName);
            });
        }
        
        // Step 3: Constant Folding (Number Obfuscation)
        if (this.settings.constFold !== false && this.level >= 2) {
            result = result.replace(/\b(\d+)\b/g, (match, num) => {
                const n = parseInt(num);
                if (isNaN(n) || n > 100000 || n < 0) return match;
                if (Math.random() > 0.7) return match; // Skip some for variation
                return this.obfuscateNumber(n);
            });
        }
        
        // Step 4: Build final output
        let output = [];
        
        // Add header
        output.push(`-- Protected with Prometheus Advanced | ${new Date().toISOString().split('T')[0]}`);
        output.push(`-- Level: ${this.level} | Strings: ${this.stats.stringsEncrypted} | Vars: ${this.stats.varsRenamed}`);
        
        // Add VM wrapper start
        if (this.settings.vmWrapper !== false) {
            const vmFunc = this.randomILVar();
            const vmEnv = this.randomILVar();
            output.push(`local ${vmFunc}=(function()`);
            
            // Add environment wrapper
            if (this.settings.envWrapper !== false) {
                output.push(this.generateEnvWrapper());
            }
            
            // Add anti-debug
            if (this.settings.antiDebug !== false) {
                output.push(this.generateAntiDebug());
            }
            
            // Add junk code
            if (this.settings.deadCode !== false) {
                output.push(this.generateJunkCode(5 + this.level * 2));
            }
            
            // Add string decryptor if needed
            if (needsDecryptor) {
                output.push(stringDecryptor.code);
            }
            
            // Add control flow
            if (this.settings.controlFlow !== false) {
                const condVar = this.randomILVar();
                const predicate = this.generateOpaquePredicate(true);
                output.push(`local ${condVar}=${predicate};`);
                output.push(`if ${condVar} then`);
                
                // More junk
                if (this.settings.deadCode !== false) {
                    output.push(this.generateJunkCode(3));
                }
                
                output.push(result);
                output.push('end;');
            } else {
                output.push(result);
            }
            
            output.push(`end);return ${vmFunc}();`);
        } else {
            // Simple wrapper without VM
            if (needsDecryptor) {
                output.push(stringDecryptor.code);
            }
            if (this.settings.deadCode !== false) {
                output.push(this.generateJunkCode(3));
            }
            output.push(result);
        }
        
        // Add watermark if enabled
        if (this.settings.watermark) {
            const wmVar = this.randomILVar();
            output.push(`local ${wmVar}="Protected by Prometheus Advanced";`);
        }
        
        return output.join('\n');
    }
}

// API Endpoint
app.post('/api/obfuscate', (req, res) => {
    try {
        const { script, settings } = req.body;
        
        if (!script || typeof script !== 'string') {
            return res.json({ success: false, error: 'No script provided' });
        }
        
        if (script.length > 500000) {
            return res.json({ success: false, error: 'Script too large (max 500KB)' });
        }
        
        const obfuscator = new LuaObfuscator(settings || {});
        const result = obfuscator.obfuscate(script);
        
        res.json({ 
            success: true, 
            result: result,
            stats: obfuscator.stats
        });
        
    } catch (error) {
        console.error('Obfuscation error:', error);
        res.json({ success: false, error: error.message });
    }
});

// Health check
app.get('/health', (req, res) => res.json({ status: 'ok', version: '2.0.0' }));

app.listen(PORT, () => console.log(`🚀 Prometheus Advanced running on port ${PORT}`));
