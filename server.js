const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(bodyParser.json({ limit: '50mb' }));
app.use(bodyParser.urlencoded({ extended: true, limit: '50mb' }));

// Homepage dengan UI
app.get('/', (req, res) => {
    res.send(`
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Prometheus Obfuscator</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #0f0f23 0%, #1a1a3e 50%, #0f0f23 100%);
            min-height: 100vh;
            padding: 20px;
            color: #fff;
        }
        .container { max-width: 1400px; margin: 0 auto; }
        h1 {
            text-align: center;
            margin-bottom: 10px;
            font-size: 2.5em;
            background: linear-gradient(90deg, #00d4ff, #00ff88, #00d4ff);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-size: 200% auto;
            animation: shine 3s linear infinite;
        }
        @keyframes shine {
            to { background-position: 200% center; }
        }
        .subtitle { text-align: center; color: #888; margin-bottom: 30px; font-size: 1.1em; }
        .editor-container { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin-bottom: 20px; }
        @media (max-width: 900px) { .editor-container { grid-template-columns: 1fr; } }
        .editor-box {
            background: rgba(255, 255, 255, 0.03);
            border-radius: 20px;
            padding: 25px;
            border: 1px solid rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
        }
        .editor-box h3 { margin-bottom: 15px; color: #00d4ff; font-size: 1.2em; }
        textarea {
            width: 100%;
            height: 450px;
            background: #0a0a1a;
            border: 2px solid #1e1e3f;
            border-radius: 15px;
            padding: 20px;
            color: #e0e0e0;
            font-family: 'Fira Code', 'Consolas', 'Monaco', monospace;
            font-size: 14px;
            resize: vertical;
            line-height: 1.6;
        }
        textarea:focus {
            outline: none;
            border-color: #00d4ff;
            box-shadow: 0 0 30px rgba(0, 212, 255, 0.2);
        }
        textarea::placeholder { color: #4a4a6a; }
        .btn-container { display: flex; justify-content: center; gap: 15px; flex-wrap: wrap; margin: 25px 0; }
        button {
            padding: 18px 45px;
            font-size: 16px;
            font-weight: 700;
            border: none;
            border-radius: 50px;
            cursor: pointer;
            transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        .btn-obfuscate {
            background: linear-gradient(135deg, #00d4ff 0%, #0099cc 100%);
            color: #000;
            box-shadow: 0 10px 40px rgba(0, 212, 255, 0.3);
        }
        .btn-obfuscate:hover {
            transform: translateY(-3px) scale(1.02);
            box-shadow: 0 20px 60px rgba(0, 212, 255, 0.4);
        }
        .btn-copy {
            background: linear-gradient(135deg, #00ff88 0%, #00cc6a 100%);
            color: #000;
            box-shadow: 0 10px 40px rgba(0, 255, 136, 0.3);
        }
        .btn-copy:hover {
            transform: translateY(-3px) scale(1.02);
            box-shadow: 0 20px 60px rgba(0, 255, 136, 0.4);
        }
        .btn-clear {
            background: linear-gradient(135deg, #ff6b6b 0%, #ee5a5a 100%);
            color: #fff;
            box-shadow: 0 10px 40px rgba(255, 107, 107, 0.3);
        }
        .btn-clear:hover {
            transform: translateY(-3px) scale(1.02);
            box-shadow: 0 20px 60px rgba(255, 107, 107, 0.4);
        }
        .btn-download {
            background: linear-gradient(135deg, #a855f7 0%, #7c3aed 100%);
            color: #fff;
            box-shadow: 0 10px 40px rgba(168, 85, 247, 0.3);
        }
        .btn-download:hover {
            transform: translateY(-3px) scale(1.02);
            box-shadow: 0 20px 60px rgba(168, 85, 247, 0.4);
        }
        .status {
            text-align: center;
            padding: 20px;
            border-radius: 15px;
            margin: 20px auto;
            max-width: 600px;
            font-weight: 600;
            display: none;
        }
        .status.success { display: block; background: rgba(0, 255, 136, 0.15); border: 2px solid #00ff88; color: #00ff88; }
        .status.error { display: block; background: rgba(255, 107, 107, 0.15); border: 2px solid #ff6b6b; color: #ff6b6b; }
        .status.loading { display: block; background: rgba(0, 212, 255, 0.15); border: 2px solid #00d4ff; color: #00d4ff; }
        .settings {
            background: rgba(255, 255, 255, 0.03);
            border-radius: 20px;
            padding: 25px;
            margin-bottom: 25px;
            border: 1px solid rgba(255, 255, 255, 0.1);
        }
        .settings h3 { margin-bottom: 20px; color: #00d4ff; }
        .settings-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 15px; }
        .setting-item {
            display: flex;
            align-items: center;
            gap: 12px;
            padding: 12px 15px;
            background: rgba(0, 0, 0, 0.2);
            border-radius: 10px;
            transition: all 0.3s ease;
        }
        .setting-item:hover { background: rgba(0, 212, 255, 0.1); }
        .setting-item input[type="checkbox"] {
            width: 22px;
            height: 22px;
            cursor: pointer;
            accent-color: #00d4ff;
        }
        .setting-item label { cursor: pointer; font-size: 15px; }
        .stats {
            display: flex;
            justify-content: center;
            gap: 30px;
            margin: 20px 0;
            flex-wrap: wrap;
        }
        .stat-item {
            background: rgba(255, 255, 255, 0.05);
            padding: 15px 25px;
            border-radius: 15px;
            text-align: center;
        }
        .stat-value { font-size: 1.8em; font-weight: 700; color: #00d4ff; }
        .stat-label { font-size: 0.9em; color: #888; margin-top: 5px; }
        footer { text-align: center; margin-top: 40px; padding: 20px; color: #555; }
        footer a { color: #00d4ff; text-decoration: none; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔒 Prometheus Obfuscator</h1>
        <p class="subtitle">Advanced Lua Script Obfuscator • Self-Hosted Edition</p>
        
        <div class="settings">
            <h3>⚙️ Obfuscation Settings</h3>
            <div class="settings-grid">
                <div class="setting-item">
                    <input type="checkbox" id="varRename" checked>
                    <label for="varRename">🔤 Variable Renaming</label>
                </div>
                <div class="setting-item">
                    <input type="checkbox" id="strEncode" checked>
                    <label for="strEncode">📝 String Encoding</label>
                </div>
                <div class="setting-item">
                    <input type="checkbox" id="controlFlow" checked>
                    <label for="controlFlow">🔀 Control Flow</label>
                </div>
                <div class="setting-item">
                    <input type="checkbox" id="wrapCode" checked>
                    <label for="wrapCode">📦 Wrap in Function</label>
                </div>
                <div class="setting-item">
                    <input type="checkbox" id="addJunk" checked>
                    <label for="addJunk">🗑️ Add Junk Code</label>
                </div>
                <div class="setting-item">
                    <input type="checkbox" id="numObfuscate">
                    <label for="numObfuscate">🔢 Number Obfuscation</label>
                </div>
            </div>
        </div>
        
        <div class="stats">
            <div class="stat-item">
                <div class="stat-value" id="inputSize">0</div>
                <div class="stat-label">Input Size (bytes)</div>
            </div>
            <div class="stat-item">
                <div class="stat-value" id="outputSize">0</div>
                <div class="stat-label">Output Size (bytes)</div>
            </div>
            <div class="stat-item">
                <div class="stat-value" id="ratio">0%</div>
                <div class="stat-label">Size Increase</div>
            </div>
        </div>
        
        <div class="editor-container">
            <div class="editor-box">
                <h3>📝 Input Script</h3>
                <textarea id="input" placeholder="-- Paste your Lua script here...

local function example()
    print('Hello World!')
    return true
end

example()"></textarea>
            </div>
            <div class="editor-box">
                <h3>🔐 Obfuscated Output</h3>
                <textarea id="output" placeholder="-- Obfuscated script will appear here..." readonly></textarea>
            </div>
        </div>
        
        <div class="btn-container">
            <button class="btn-obfuscate" onclick="obfuscate()">🔒 Obfuscate</button>
            <button class="btn-copy" onclick="copyOutput()">📋 Copy</button>
            <button class="btn-download" onclick="downloadOutput()">💾 Download</button>
            <button class="btn-clear" onclick="clearAll()">🗑️ Clear</button>
        </div>
        
        <div id="status" class="status"></div>
        
        <footer>
            <p>Prometheus Obfuscator • Self-Hosted • Made with ❤️</p>
        </footer>
    </div>

    <script>
        const inputEl = document.getElementById('input');
        const outputEl = document.getElementById('output');
        
        inputEl.addEventListener('input', updateInputStats);
        
        function updateInputStats() {
            document.getElementById('inputSize').textContent = inputEl.value.length;
        }
        
        function updateOutputStats() {
            const inputLen = inputEl.value.length;
            const outputLen = outputEl.value.length;
            document.getElementById('outputSize').textContent = outputLen;
            if (inputLen > 0) {
                const ratio = Math.round((outputLen / inputLen - 1) * 100);
                document.getElementById('ratio').textContent = (ratio >= 0 ? '+' : '') + ratio + '%';
            }
        }

        function showStatus(message, type) {
            const status = document.getElementById('status');
            status.textContent = message;
            status.className = 'status ' + type;
        }

        async function obfuscate() {
            const input = inputEl.value;
            
            if (!input.trim()) {
                showStatus('❌ Please enter a script to obfuscate!', 'error');
                return;
            }
            
            showStatus('⏳ Obfuscating... Please wait...', 'loading');
            
            const settings = {
                varRename: document.getElementById('varRename').checked,
                strEncode: document.getElementById('strEncode').checked,
                controlFlow: document.getElementById('controlFlow').checked,
                wrapCode: document.getElementById('wrapCode').checked,
                addJunk: document.getElementById('addJunk').checked,
                numObfuscate: document.getElementById('numObfuscate').checked
            };
            
            try {
                const response = await fetch('/api/obfuscate', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ script: input, settings: settings })
                });
                
                const data = await response.json();
                
                if (data.success) {
                    outputEl.value = data.result;
                    updateOutputStats();
                    showStatus('✅ Obfuscation successful! Size: ' + data.result.length + ' bytes', 'success');
                } else {
                    showStatus('❌ Error: ' + data.error, 'error');
                }
            } catch (error) {
                showStatus('❌ Network error: ' + error.message, 'error');
            }
        }

        function copyOutput() {
            if (!outputEl.value) {
                showStatus('❌ No output to copy!', 'error');
                return;
            }
            navigator.clipboard.writeText(outputEl.value).then(() => {
                showStatus('✅ Copied to clipboard!', 'success');
            }).catch(() => {
                outputEl.select();
                document.execCommand('copy');
                showStatus('✅ Copied to clipboard!', 'success');
            });
        }

        function downloadOutput() {
            if (!outputEl.value) {
                showStatus('❌ No output to download!', 'error');
                return;
            }
            const blob = new Blob([outputEl.value], { type: 'text/plain' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = 'obfuscated_' + Date.now() + '.lua';
            a.click();
            URL.revokeObjectURL(url);
            showStatus('✅ Downloaded!', 'success');
        }

        function clearAll() {
            inputEl.value = '';
            outputEl.value = '';
            document.getElementById('status').className = 'status';
            document.getElementById('inputSize').textContent = '0';
            document.getElementById('outputSize').textContent = '0';
            document.getElementById('ratio').textContent = '0%';
        }
    </script>
</body>
</html>
    `);
});

// API Obfuscate
app.post('/api/obfuscate', (req, res) => {
    try {
        const { script, settings } = req.body;
        
        if (!script || typeof script !== 'string') {
            return res.json({ success: false, error: 'No script provided' });
        }
        
        const result = obfuscateScript(script, settings || {});
        res.json({ success: true, result: result });
        
    } catch (error) {
        res.json({ success: false, error: error.message });
    }
});

// Obfuscator Engine
function obfuscateScript(script, settings) {
    let result = script;
    
    function randomVar(len = 8) {
        const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_';
        let r = chars[Math.floor(Math.random() * 53)];
        for (let i = 1; i < len; i++) r += chars[Math.floor(Math.random() * 53)];
        return r;
    }
    
    function randomNum() { return Math.floor(Math.random() * 9000) + 1000; }
    
    const reserved = ['and','break','do','else','elseif','end','false','for','function','goto','if','in','local','nil','not','or','repeat','return','then','true','until','while','game','workspace','script','Instance','Vector3','CFrame','Color3','UDim2','Enum','math','string','table','coroutine','print','warn','error','pcall','xpcall','loadstring','require','spawn','wait','task','tick','typeof','type','tostring','tonumber','pairs','ipairs','next','select','unpack','setmetatable','getmetatable','rawget','rawset','getfenv','setfenv','getgenv','getrenv'];
    
    // String encoding
    if (settings.strEncode !== false) {
        result = result.replace(/"([^"\\]*(\\.[^"\\]*)*)"/g, (m, s) => {
            if (!s || s.length > 80 || s.length === 0) return m;
            return 'string.char(' + [...s].map(c => c.charCodeAt(0)).join(',') + ')';
        });
        result = result.replace(/'([^'\\]*(\\.[^'\\]*)*)'/g, (m, s) => {
            if (!s || s.length > 80 || s.length === 0) return m;
            return 'string.char(' + [...s].map(c => c.charCodeAt(0)).join(',') + ')';
        });
    }
    
    // Variable renaming
    if (settings.varRename !== false) {
        const varMap = new Map();
        const localPattern = /local\s+([a-zA-Z_][a-zA-Z0-9_]*)/g;
        let match;
        while ((match = localPattern.exec(script)) !== null) {
            const v = match[1];
            if (!varMap.has(v) && !reserved.includes(v)) {
                varMap.set(v, randomVar(6 + Math.floor(Math.random() * 6)));
            }
        }
        varMap.forEach((newN, oldN) => {
            result = result.replace(new RegExp('\\b' + oldN + '\\b', 'g'), newN);
        });
    }
    
    // Number obfuscation
    if (settings.numObfuscate) {
        result = result.replace(/\b(\d+)\b/g, (m, n) => {
            const num = parseInt(n);
            if (isNaN(num) || num > 10000) return m;
            const a = Math.floor(Math.random() * num);
            const b = num - a;
            return '(' + a + '+' + b + ')';
        });
    }
    
    // Add junk code
    if (settings.addJunk !== false) {
        const junk = [];
        for (let i = 0; i < 5; i++) {
            junk.push('local ' + randomVar(10) + '=' + randomNum() + ';');
        }
        junk.push('local ' + randomVar(8) + '=function()return ' + randomNum() + ' end;');
        result = junk.join('') + result;
    }
    
    // Control flow
    if (settings.controlFlow !== false) {
        const marker = randomVar(6);
        result = 'local ' + marker + '=true;if ' + marker + ' then ' + result + ' end;';
    }
    
    // Wrap in function
    if (settings.wrapCode !== false) {
        const fn = randomVar(12);
        result = 'local ' + fn + '=(function()' + result + ' end);return ' + fn + '();';
    }
    
    // Header
    result = '-- Obfuscated with Prometheus Web | ' + new Date().toISOString().split('T')[0] + '\n' + result;
    
    return result;
}

// Health check
app.get('/health', (req, res) => res.json({ status: 'ok' }));

app.listen(PORT, () => console.log('🚀 Server running on port ' + PORT));
