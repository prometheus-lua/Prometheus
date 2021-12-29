return {
	WrapInFunction = require("obfuscator.steps.WrapInFunction");
	SplitStrings   = require("obfuscator.steps.SplitStrings");
	LocalsToTable  = require("obfuscator.steps.LocalsToTable");
	Vmify          = require("obfuscator.steps.Vmify");
	ConstantArray  = require("obfuscator.steps.ConstantArray");
	ProxifyLocals  = require("obfuscator.steps.ProxifyLocals");
}