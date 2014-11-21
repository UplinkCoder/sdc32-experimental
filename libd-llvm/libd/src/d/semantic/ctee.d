module d.semantic.ctee;

import d.ast.expression;
import d.ir.expression;
import d.ir.type;
import d.semantic.caster;
import d.semantic.expression;
import d.semantic.semantic;

alias TernaryExpression = d.ir.expression.TernaryExpression;
alias BinaryExpression = d.ir.expression.BinaryExpression;
alias UnaryExpression = d.ir.expression.UnaryExpression;
alias CallExpression = d.ir.expression.CallExpression;
alias NewExpression = d.ir.expression.NewExpression;
alias IndexExpression = d.ir.expression.IndexExpression;
alias SliceExpression = d.ir.expression.SliceExpression;
alias AssertExpression = d.ir.expression.AssertExpression;

alias PointerType = d.ir.type.PointerType;
alias SliceType = d.ir.type.SliceType;
alias ArrayType = d.ir.type.ArrayType;
alias FunctionType = d.ir.type.FunctionType;

import util.visitor;
import d.ast.base;
T as(T)(Node n) {
	return cast(T) n;
}



struct CTEEVisitor
{
	SemanticPass pass;

	CompileTimeExpression visit (AstExpression e) {
		return this.dispatch!((e) {
//			return pass.raiseCondition!Expression(e.location, typeid(e).toString() ~ " is not supported");
			return null;
		})(e);
	}

	CompileTimeExpression visit (IdentifierExpression e) {
		return visit(ExpressionVisitor(pass).visit(e));
	}

	CompileTimeExpression visit (IntegerLiteral!true e) {
		return e;
	}

	CompileTimeExpression visit (IntegerLiteral!false e) {
		return e;
	}

	CompileTimeExpression visit (StringLiteral e) {
		return e;
	}
	
	CompileTimeExpression visit (BooleanLiteral e) {
		return e;
	}

	CompileTimeExpression visit (CharacterLiteral e) {
		return e;
	}

	CompileTimeExpression visit(NullLiteral e) {
		return e;
	}

	CompileTimeExpression visit(AstBinaryExpression e) {

		auto lhs = visit(e.lhs);
		auto rhs = visit(e.rhs);
		auto op = e.op;
		import std.stdio;
		writeln("CTEE lhs: "~ typeid(e.lhs).toString() ~ " rhs: " ~ typeid(e.rhs).toString());
		
		
		QualType type;
		switch(op) with(BinaryOp) {
			case Concat :
			case ConcatAssign :
				if (auto clhs = cast(StringLiteral) lhs) 
				if (auto crhs = cast(StringLiteral) rhs)  { 
					return new StringLiteral(e.location, clhs.value ~ crhs.value);
				} 
				goto default;

			default : return null;

		}
		
	}
}

