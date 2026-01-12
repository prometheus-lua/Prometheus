const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const crypto = require('crypto');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(bodyParser.json({ limit: '50mb' }));
app.use(bodyParser.urlencoded({ extended: true, limit: '50mb' }));

// ... (Bagian HTML tetap sama, tidak perlu diubah) ...
// LANGSUNG KE BAGIAN CLASS LUAOBFUSCATOR

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

    // ... (Helper functions tetap sama: generateKey, randomVar, dll) ...
    // Copy helper functions dari kode sebelumnya

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
        const chars = ['I', 'l', '1'];
        let result = chars[Math.floor(Math.random() * 2)];
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

    obfuscateNumber(num) {
        if (this.level < 2) return num.toString();
        const methods = [
            () => { const a = Math.floor(Math.random() * num); const b = num - a; return `(${a}+${b})`; },
            () => { const a = num + Math.floor(Math.random() * 1000); const b = a - num; return `(${a}-${b})`; },
            () => { const a = Math.floor(Math.random() * 65535); const b = num ^ a; return `bit32.bxor(${a},${b})`; },
            () => { 
                const divisors = [2, 4, 5, 8, 10, 16, 20, 25];
                for (const d of divisors) { if (num % d === 0) return `(${num/d}*${d})`; }
                return num.toString();
            }
        ];
        return methods[Math.floor(Math.random() * methods.length)]();
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
            const type = Math.floor(Math.random() * 4); // Simplified junk
            const v1 = this.randomILVar();
            const n1 = this.randomInt();
            if(type===0) junk.push(`local ${v1}=${n1};`);
            else if(type===1) junk.push(`local ${v1}=function()return ${n1} end;`);
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

    // MAIN OBFUSCATE FUNCTION (YANG DIPERBAIKI)
    obfuscate(script) {
        let result = script;
        const stringDecryptor = this.generateStringDecryptor();
        let needsDecryptor = false;
        
        // ... (String Encryption & Variable Mangling steps tetap sama) ...
        if (this.settings.strEncrypt !== false) {
            result = result.replace(/"([^"\\]*(\\.[^"\\]*)*)"/g, (match, content) => {
                if (content.length === 0 || content.length > 150) return match;
                const encrypted = this.encryptString(content);
                if (encrypted) { needsDecryptor = true; return `${stringDecryptor.name}(${encrypted.data},${encrypted.key})`; }
                return match;
            });
            result = result.replace(/'([^'\\]*(\\.[^'\\]*)*)'/g, (match, content) => {
                if (content.length === 0 || content.length > 150) return match;
                const encrypted = this.encryptString(content);
                if (encrypted) { needsDecryptor = true; return `${stringDecryptor.name}(${encrypted.data},${encrypted.key})`; }
                return match;
            });
        }
        
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

        // Build final output
        let output = [];
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
                
                // FIX: Watermark di sini!
                if (this.settings.watermark) {
                    const wmVar = this.randomILVar();
                    output.push(`local ${wmVar}="Protected by Prometheus Advanced";`);
                }
                
                output.push('end;');
            } else {
                output.push(result);
                // FIX: Watermark di sini!
                if (this.settings.watermark) {
                    const wmVar = this.randomILVar();
                    output.push(`local ${wmVar}="Protected by Prometheus Advanced";`);
                }
            }
            
            output.push(`end);return ${vmFunc}();`);
        } else {
            if (needsDecryptor) output.push(stringDecryptor.code);
            output.push(result);
            if (this.settings.watermark) {
                const wmVar = this.randomILVar();
                output.push(`local ${wmVar}="Protected by Prometheus Advanced";`);
            }
        }
        
        return output.join('\n');
    }
}

// ... (API Endpoint & App Listen tetap sama) ...
// Copy bagian bawah dari kode sebelumnya
