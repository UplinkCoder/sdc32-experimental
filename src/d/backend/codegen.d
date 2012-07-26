module d.backend.codegen;

import d.ast.dmodule;

import util.visitor;

import llvm.c.Analysis;
import llvm.c.Core;

import std.string;

auto codeGen(Module m) {
	auto builder = LLVMCreateBuilder();
	auto dmodule = LLVMModuleCreateWithName(m.location.filename.toStringz());
	
	// Dump module content on exit (for debug purpose).
	scope(exit) LLVMDumpModule(dmodule);
	
	auto cg = new DeclarationGen(dmodule, builder);
	foreach(decl; m.declarations) {
		cg.visit(decl);
	}
	
	return dmodule;
}

import d.ast.declaration;
import d.ast.dfunction;

class DeclarationGen {
	private LLVMBuilderRef builder;
	private LLVMModuleRef dmodule;
	
	private ExpressionGen expressionGen;
	private TypeGen typeGen;
	
	struct VariableEntry {
		LLVMValueRef value;
		LLVMValueRef address;
	}
	
	VariableEntry[string] variables;
	
	this(LLVMModuleRef dmodule, LLVMBuilderRef builder) {
		this.builder = builder;
		this.dmodule = dmodule;
		
		typeGen = new TypeGen();
		expressionGen = new ExpressionGen(builder, this, typeGen);
	}
	
final:
	void visit(Declaration d) {
		this.dispatch(d);
	}
	
	void visit(FunctionDefinition f) {
		auto funType = LLVMFunctionType(typeGen.visit(f.returnType), null, 0, false);
		auto fun = LLVMAddFunction(dmodule, toStringz(f.name), funType);
		
		// Instruction block.
		auto basicBlock = LLVMAppendBasicBlock(fun, "");
		LLVMPositionBuilderAtEnd(builder, basicBlock);
		
		(new StatementGen(builder, this, expressionGen)).visit(f.fbody);
		
		LLVMVerifyFunction(fun, LLVMVerifierFailureAction.PrintMessage);
	}
	
	// TODO: this should be gone way before codegen. Delete in the future when passes are ready.
	void visit(VariablesDeclaration decls) {
		foreach(var; decls.variables) {
			visit(var);
		}
	}
	
	void visit(VariableDeclaration var) {
		// Backup current block
		auto backupCurrentBlock = LLVMGetInsertBlock(builder);
		LLVMPositionBuilderAtEnd(builder, LLVMGetFirstBasicBlock(LLVMGetBasicBlockParent(backupCurrentBlock)));
		
		// Create an alloca for this variable.
		auto alloca = LLVMBuildAlloca(builder, typeGen.visit(var.type), "");
		
		LLVMPositionBuilderAtEnd(builder, backupCurrentBlock);
		
		// Store the initial value into the alloca.
		auto value = expressionGen.visit(var.value);
		LLVMBuildStore(builder, value, alloca);
		
		variables[var.name] = VariableEntry(value, alloca);
	}
}

import d.ast.statement;

class StatementGen {
	private LLVMBuilderRef builder;
	
	private DeclarationGen declarationGen;
	private ExpressionGen expressionGen;
	
	this(LLVMBuilderRef builder, DeclarationGen declarationGen, ExpressionGen expressionGen){
		this.builder = builder;
		this.declarationGen = declarationGen;
		this.expressionGen = expressionGen;
	}
	
final:
	void visit(Statement s) {
		this.dispatch(s);
	}
	
	void visit(DeclarationStatement d) {
		declarationGen.visit(d.declaration);
	}
	
	void visit(ExpressionStatement e) {
		expressionGen.visit(e.expression);
	}
	
	void visit(BlockStatement b) {
		foreach(s; b.statements) {
			visit(s);
		}
	}
	
	void visit(IfStatement ifs) {
		auto fun = LLVMGetBasicBlockParent(LLVMGetInsertBlock(builder));
		
		auto thenBB = LLVMAppendBasicBlock(fun, "then");
		auto elseBB = LLVMAppendBasicBlock(fun, "else");
		auto mergeBB = LLVMAppendBasicBlock(fun, "merge");
		
		LLVMBuildCondBr(builder, expressionGen.visit(ifs.condition), thenBB, elseBB);
		
		// Emit then value
		LLVMPositionBuilderAtEnd(builder, thenBB);
		
		visit(ifs.then);
		
		// Conclude that block.
		LLVMBuildBr(builder, mergeBB);
		
		// Codegen of else can change the current block, so we put everything in order.
		thenBB = LLVMGetInsertBlock(builder);
		LLVMMoveBasicBlockAfter(elseBB, thenBB);
		LLVMPositionBuilderAtEnd(builder, elseBB);
		
		// TODO: Codegen for else.
		
		// Conclude that block.
		LLVMBuildBr(builder, mergeBB);
		
		// Codegen of else can change the current block, so we put everything in order.
		elseBB = LLVMGetInsertBlock(builder);
		LLVMMoveBasicBlockAfter(mergeBB, elseBB);
		LLVMPositionBuilderAtEnd(builder, mergeBB);
		
		// TODO: generate phi to merge everything back.
	}
	
	void visit(ReturnStatement r) {
		LLVMBuildRet(builder, expressionGen.visit(r.value));
	}
}

import d.ast.expression;

class ExpressionGen {
	private LLVMBuilderRef builder;
	
	private DeclarationGen declarationGen;
	private TypeGen typeGen;
	
	this(LLVMBuilderRef builder, DeclarationGen declarationGen, TypeGen typeGen) {
		this.builder = builder;
		this.declarationGen = declarationGen;
		this.typeGen = typeGen;
	}
	
final:
	LLVMValueRef visit(Expression e) {
		return this.dispatch(e);
	}
	
	LLVMValueRef visit(IntegerLiteral!true il) {
		return LLVMConstInt(typeGen.visit(il.type), il.value, true);
	}
	
	LLVMValueRef visit(IntegerLiteral!false il) {
		return LLVMConstInt(typeGen.visit(il.type), il.value, false);
	}
	
	LLVMValueRef visit(AssignExpression e) {
		auto value = visit(e.rhs);
		
		auto lhs = cast(IdentifierExpression) e.lhs;
		auto variable = &(declarationGen.variables[lhs.identifier.name]);
		variable.value = value;
		
		LLVMBuildStore(builder, value, variable.address);
		
		return value;
	}
	
	private auto handleBinaryOp(alias LLVMBuildOp, BinaryExpression)(BinaryExpression e) {
		return LLVMBuildOp(builder, visit(e.lhs), visit(e.rhs), "");
	}
	
	private auto handleBinaryOp(alias LLVMSignedBuildOp, alias LLVMUnsignedBuildOp, BinaryExpression)(BinaryExpression e) {
		typeGen.visit(e.type);
		if(typeGen.isSigned) {
			return handleBinaryOp!LLVMSignedBuildOp(e);
		} else {
			return handleBinaryOp!LLVMUnsignedBuildOp(e);
		}
	}
	
	LLVMValueRef visit(AddExpression add) {
		return handleBinaryOp!LLVMBuildAdd(add);
	}
	
	LLVMValueRef visit(SubExpression sub) {
		return handleBinaryOp!LLVMBuildSub(sub);
	}
	
	LLVMValueRef visit(MulExpression mul) {
		return handleBinaryOp!LLVMBuildMul(mul);
	}
	
	LLVMValueRef visit(DivExpression div) {
		return handleBinaryOp!(LLVMBuildSDiv, LLVMBuildUDiv)(div);
	}
	
	LLVMValueRef visit(ModExpression mod) {
		return handleBinaryOp!(LLVMBuildSRem, LLVMBuildURem)(mod);
	}
	
	LLVMValueRef visit(IdentifierExpression e) {
		return declarationGen.variables[e.identifier.name].value;
	}
	
	private auto handleComparaison(LLVMIntPredicate predicate, BinaryExpression)(BinaryExpression e) {
		return handleBinaryOp!(function(LLVMBuilderRef builder, LLVMValueRef lhs, LLVMValueRef rhs, const char* name) {
			return LLVMBuildICmp(builder, predicate, lhs, rhs, name);
		})(e);
	}
	
	private auto handleComparaison(LLVMIntPredicate signedPredicate, LLVMIntPredicate unsignedPredicate, BinaryExpression)(BinaryExpression e) {
		typeGen.visit(e.type);
		if(typeGen.isSigned) {
			return handleComparaison!signedPredicate(e);
		} else {
			return handleComparaison!unsignedPredicate(e);
		}
	}
	
	LLVMValueRef visit(EqualityExpression e) {
		return handleComparaison!(LLVMIntPredicate.EQ)(e);
	}
	
	LLVMValueRef visit(NotEqualityExpression e) {
		return handleComparaison!(LLVMIntPredicate.NE)(e);
	}
	
	// TODO: handled signed and unsigned !
	LLVMValueRef visit(LessExpression e) {
		return handleComparaison!(LLVMIntPredicate.SLT, LLVMIntPredicate.ULT)(e);
	}
	
	LLVMValueRef visit(LessEqualExpression e) {
		return handleComparaison!(LLVMIntPredicate.SLE, LLVMIntPredicate.ULE)(e);
	}
	
	LLVMValueRef visit(GreaterExpression e) {
		return handleComparaison!(LLVMIntPredicate.SGT, LLVMIntPredicate.UGT)(e);
	}
	
	LLVMValueRef visit(GreaterEqualExpression e) {
		return handleComparaison!(LLVMIntPredicate.SGE, LLVMIntPredicate.UGE)(e);
	}
	
	LLVMValueRef visit(PadExpression e) {
		auto type = typeGen.visit(e.type);
		
		typeGen.visit(e.expression.type);
		if(typeGen.isSigned) {
			return LLVMBuildSExt(builder, visit(e.expression), type, "");
		} else {
			return LLVMBuildZExt(builder, visit(e.expression), type, "");
		}
	}
	
	LLVMValueRef visit(TruncateExpression e) {
		return LLVMBuildTrunc(builder, visit(e.expression), typeGen.visit(e.type), "");
	}
}

import d.ast.type;

class TypeGen {
	bool isSigned;
	
	LLVMTypeRef visit(Type t) {
		isSigned = true;
		return this.dispatch(t);
	}
	
	LLVMTypeRef visit(BuiltinType!bool) {
		isSigned = false;
		return LLVMInt1Type();
	}
	
	LLVMTypeRef visit(BuiltinType!byte) {
		isSigned = true;
		return LLVMInt8Type();
	}
	
	LLVMTypeRef visit(BuiltinType!ubyte) {
		isSigned = false;
		return LLVMInt8Type();
	}
	
	LLVMTypeRef visit(BuiltinType!short) {
		isSigned = true;
		return LLVMInt16Type();
	}
	
	LLVMTypeRef visit(BuiltinType!ushort) {
		isSigned = false;
		return LLVMInt16Type();
	}
	
	LLVMTypeRef visit(BuiltinType!int) {
		isSigned = true;
		return LLVMInt32Type();
	}
	
	LLVMTypeRef visit(BuiltinType!uint) {
		isSigned = false;
		return LLVMInt32Type();
	}
	
	LLVMTypeRef visit(BuiltinType!long) {
		isSigned = true;
		return LLVMInt64Type();
	}
	
	LLVMTypeRef visit(BuiltinType!ulong) {
		isSigned = false;
		return LLVMInt64Type();
	}
}
