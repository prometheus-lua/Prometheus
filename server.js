const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const crypto = require('crypto');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(bodyParser.json({ limit: '50mb' }));
app.use(bodyParser.urlencoded({ extended: true, limit: '50mb' }));

// ==================== HTML UI ====================
app.get('/', (req, res) => {
    res.send(`
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Prometheus Advanced</title>
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
            font-size: 2.5em;
            background: linear-gradient(90deg, #ff0080, #00d4ff, #00ff88);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        .subtitle { text-align: center; color: #666; margin-bottom: 25px; }
        .editor-container { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin-bottom: 20px; }
        @media (max-width: 900px) { .editor-container { grid-template-columns: 1fr; } }
        .editor-box {
            background: rgba(255, 255, 255, 0.02);
            border-radius: 12px;
            padding: 15px;
            border: 1px solid rgba(255, 255, 255, 0.08);
        }
        .editor-box h3 { margin-bottom: 10px; color: #00d4ff; }
        textarea {
            width: 100%;
            height: 400px;
            background: #08080f;
            border: 1px solid #1a1a2f;
            border-radius: 8px;
            padding: 15px;
            color: #a0e0a0;
            font-family: 'Consolas', monospace;
            font-size: 13px;
            resize: vertical;
        }
        textarea:focus { outline: none; border-color: #00d4ff; }
        .btn-container { display: flex; justify-content: center; gap: 10px; flex-wrap: wrap; margin: 20px 0; }
        button {
            padding: 12px 30px;
            font-size: 14px;
            font-weight: 700;
            border: none;
            border-radius: 50px;
            cursor: pointer;
            transition: all 0.3s ease;
        }
        .btn-obfuscate { background: linear-gradient(135deg, #ff0080 0%, #7928ca 100%); color: #fff; }
        .btn-obfuscate:hover { transform: translateY(-2px); box-shadow: 0 5px 15px rgba(255, 0, 128, 0.3); }
        .btn-copy { background: #00d4ff; color: #000; }
        .btn-clear { background: #ff4757; color: #fff; }
        .status { text-align: center; padding: 10px; margin: 10px auto; max-width: 600px; border-radius: 8px; display: none; }
        .status.success { background: rgba(0, 255, 136, 0.1); color: #00ff88; border: 1px solid #00ff88; }
        .status.error { background: rgba(255, 71, 87, 0.1); color: #ff4757; border: 1px solid #ff4757; }
        .status.loading { background: rgba(0, 212, 255, 0.1); color: #00d4ff; border: 1px solid #00d4ff; }
        .settings {
            background: rgba(255, 255, 255, 0.02);
            border-radius: 12px;
            padding: 15px;
            margin-bottom: 20px;
            border: 1px solid rgba(255, 255, 255, 0.08);
        }
        .settings-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 10px; }
        .setting-item { display: flex; align-items: center; gap: 8px; color: #ccc; }
        .setting-item input { accent-color: #ff0080; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔐 Prometheus Advanced</h1>
        <p class="subtitle">Self-Hosted Lua Obfuscator</p>
        
        <div class="settings">
            <div class="settings-grid">
                <div class="setting-item"><input type="checkbox" id="strEncrypt" checked><label for="strEncrypt">String Encryption</label></div>
                <div class="setting-item"><input type="checkbox" id="varMangle" checked><label for="varMangle">Variable Renaming</label></div>
                <div class="setting-item"><input type="checkbox" id="controlFlow" checked><label for="controlFlow">Control Flow</label></div>
                <div class="setting-item"><input type="checkbox" id="deadCode" checked><label for="deadCode">Dead Code</label></div>
                <div class="setting-item"><input type="checkbox" id="vmWrapper" checked><label for="vmWrapper">VM Wrapper</label></div>
                <div class="setting-item"><input type="checkbox" id="antiDebug" checked><label for="antiDebug">Anti-Debug</label></div>
                <div class="setting-item"><input type="checkbox" id="envWrapper" checked><label for="envWrapper">Env Wrapper</label></div>
                <div class="setting-item"><input type="checkbox" id="watermark" checked><label for="watermark">Watermark</label></div>
            </div>
        </div>
        
        <div class="editor-container">
            <div class="editor-box">
                <h3>📝 Input Script</h3>
                <textarea id="input" placeholder="print('Hello World')"></textarea>
            </div>
            <div class="editor-box">
                <h3>🔐 Output</h3>
                <textarea id="output" readonly></textarea>
            </div>
        </div>
        
        <div class="btn-container">
            <button class="btn-obfuscate" onclick="obfuscate()">Protect Script</button>
            <button class="btn-copy" onclick="copyOutput()">Copy</button>
            <button class="btn-clear" onclick="clearAll()">Clear</button>
        </div>
        
        <div id="status" class="status"></div>
    </div>

    <script>
        function showStatus(msg, type) {
            const el = document.getElementById('status');
            el.textContent = msg;
            el.className = 'status ' + type;
            el.style.display = 'block';
        }

        async function obfuscate() {
            const input = document.getElementById('input').value;
            if (!input.trim()) return showStatus('Please enter a script', 'error');
            
            showStatus('Protecting...', 'loading');
            
            const settings = {
                strEncrypt: document.getElementById('strEncrypt').checked,
                varMangle: document.getElementById('varMangle').checked,
                controlFlow: document.getElementById('controlFlow').checked,
                deadCode: document.getElementById('deadCode').checked,
                vmWrapper: document.getElementById('vmWrapper').checked,
                antiDebug: document.getElementById('antiDebug').checked,
                envWrapper: document.getElementById('envWrapper').checked,
                watermark: document.getElementById('watermark').checked,
                level: 3
            };

            try {
                const res = await fetch('/api/obfuscate', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({script: input, settings})
                });
                const data = await res.json();
                
                if (data.success) {
                    document.getElementById('output').value = data.result;
                    showStatus(`Success! (${data.result.length} bytes)`, 'success');
                } else {
                    showStatus('Error: ' + data.error, 'error');
                }
            } catch (e) {
                showStatus('Network Error: ' + e.message, 'error');
            }
        }

        function copyOutput() {
            const out = document.getElementById('output');
            if(!out.value) return;
            out.select();
            document.execCommand('copy');
            showStatus('Copied to clipboard!', 'success');
        }

        function clearAll() {
            document.getElementById('input').value = '';
            document.getElementById('output').value = '';
            document.getElementById('status').style.display = 'none';
        }
    </script>
</body>
</html>
    `);
});

// ==================== OBFUSCATOR LOGIC ====================

class LuaObfuscator {
    constructor(settings = {}) {
        this.settings = settings;
        this.level = settings.level || 3;
        this.stats = { stringsEncrypted: 0, varsRenamed: 0 };
        this.encryptionKey = this.generateKey(16);
        this.varCounter = 0;
        this.reserved = new Set([
            'and','break','do','else','elseif','end','false','for','function','goto',
            'if','in','local','nil','not','or','repeat','return','then','true','until','while',
            'game','workspace','script','print','warn','error','pcall','loadstring'
        ]);
    }

    generateKey(length) {
        const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
        let result = '';
        for (let i = 0; i < length; i++) result += chars.charAt(Math.floor(Math.random() * chars.length));
        return result;
    }

    randomILVar() {
        const chars = ['I', 'l', '1'];
        let result = chars[Math.floor(Math.random() * 2)];
        let length = 8 + Math.floor(Math.random() * 8);
        for (let i = 1; i < length; i++) result += chars[Math.floor(Math.random() * chars.length)];
        return result;
    }

    randomInt(min = 1000, max = 99999) {
        return Math.floor(Math.random() * (max - min + 1)) + min;
    }

    xorEncrypt(str, key) {
        let result = [];
        for (let i = 0; i < str.length; i++) {
            result.push(str.charCodeAt(i) ^ key.charCodeAt(i % key.length));
        }
        return result;
    }

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

    encryptString(str) {
        if (str.length === 0) return '""';
        if (str.length > 200) return null;
        this.stats.stringsEncrypted++;
        const encrypted = this.xorEncrypt(str, this.encryptionKey);
        return { data: `{${encrypted.join(',')}}`, key: `"${this.encryptionKey}"` };
    }

    generateJunkCode(count = 5) {
        const junk = [];
        for (let i = 0; i < count; i++) {
            const v1 = this.randomILVar();
            const n1 = this.randomInt();
            junk.push(`local ${v1}=${n1};`);
        }
        return junk.join('');
    }

    generateOpaquePredicate(isTrue = true) {
        const n1 = this.randomInt(1, 1000);
        return isTrue ? `(${n1}==${n1})` : `(${n1}~=${n1})`;
    }

    generateAntiDebug() {
        const checkVar = this.randomILVar();
        return `local ${checkVar}=(function()pcall(function()if getgenv and(getgenv().SimpleSpy or getgenv().RemoteSpy)then while true do end end end)return true end)();`;
    }

    generateEnvWrapper() {
        const envVar = this.randomILVar();
        return `local ${envVar}=setmetatable({},{__index=function(s,k)return rawget(s,k)or getfenv()[k]or _G[key]end});setfenv(1,${envVar});`;
    }

    obfuscate(script) {
        let result = script;
        const stringDecryptor = this.generateStringDecryptor();
        let needsDecryptor = false;
        
        // 1. String Encryption
        if (this.settings.strEncrypt !== false) {
            result = result.replace(/"([^"\\]*(\\.[^"\\]*)*)"/g, (match, content) => {
                if (content.length === 0 || content.length > 150) return match;
                const encrypted = this.encryptString(content);
                if (encrypted) {
                    needsDecryptor = true;
                    return `${stringDecryptor.name}(${encrypted.data},${encrypted.key})`;
                }
                return match;
            });
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
        
        // 2. Variable Mangling
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
        
        // 3. Final Build
        let output = [];
        
        // Header (Fixed Newline)
        output.push(`-- Protected with Prometheus Advanced | ${new Date().toISOString().split('T')[0]}`);
        
        if (this.settings.vmWrapper !== false) {
            const vmFunc = this.randomILVar();
            output.push(`local ${vmFunc}=(function()`);
            
            if (this.settings.envWrapper !== false) output.push(this.generateEnvWrapper());
            if (this.settings.antiDebug !== false) output.push(this.generateAntiDebug());
            if (this.settings.deadCode !== false) output.push(this.generateJunkCode(5));
            if (needsDecryptor) output.push(stringDecryptor.code);
            
            if (this.settings.controlFlow !== false) {
                const condVar = this.randomILVar();
                output.push(`local ${condVar}=${this.generateOpaquePredicate(true)};`);
                output.push(`if ${condVar} then`);
                output.push(result);
                
                // Watermark INSIDE control flow
                if (this.settings.watermark) {
                    output.push(`local ${this.randomILVar()}="Protected by Prometheus";`);
                }
                
                output.push('end;');
            } else {
                output.push(result);
                // Watermark INSIDE wrapper
                if (this.settings.watermark) {
                    output.push(`local ${this.randomILVar()}="Protected by Prometheus";`);
                }
            }
            
            output.push(`end);return ${vmFunc}();`);
        } else {
            if (needsDecryptor) output.push(stringDecryptor.code);
            output.push(result);
            if (this.settings.watermark) {
                output.push(`local ${this.randomILVar()}="Protected by Prometheus";`);
            }
        }
        
        return output.join('\n');
    }
}

// API Route
app.post('/api/obfuscate', (req, res) => {
    try {
        const { script, settings } = req.body;
        if (!script || typeof script !== 'string') return res.json({ success: false, error: 'No script' });
        
        const obfuscator = new LuaObfuscator(settings || {});
        const result = obfuscator.obfuscate(script);
        
        res.json({ success: true, result: result });
    } catch (error) {
        res.json({ success: false, error: error.message });
    }
});

// Start Server (BIND TO 0.0.0.0 for Render)
app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 Prometheus running on port ${PORT}`);
});
