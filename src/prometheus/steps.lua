return {
	WrapInFunction = require("prometheus.steps.WrapInFunction");
	SplitStrings   = require("prometheus.steps.SplitStrings");
	LocalsToTable  = require("prometheus.steps.LocalsToTable");
	Vmify          = require("prometheus.steps.Vmify");
	ConstantArray  = require("prometheus.steps.ConstantArray");
	ProxifyLocals  = require("prometheus.steps.ProxifyLocals");
	BreakBeautify  = require("prometheus.steps.BreakBeautify");
	EncryptStrings = require("prometheus.steps.EncryptStrings");
	NumbersToExpressions = require("prometheus.steps.NumbersToExpressions");
}