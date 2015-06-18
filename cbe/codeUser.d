import cbe.codeGen;

// create a MainFunction

auto cu = new CompilationUnit();
cu.addFunction("main", new CType(CTypeEnum.cvoid), [], 
	new CStatement(new CReturnStatement()));
	// adds void main() { return ; } 
cu.addFunction("add", new CType(CTypeEnum.cint), [new CVariable("a",CTypeEnum.cint), auto param1 = new CVariable("b", CTypeEnum.cint)],
	new CStatement(new CBlockStatement([new CStatement(new CExpressionStatement(new CExpression(new CBinaryExpression())))]))));
