module d.ctfe;
import std.array:array;
import std.algorithm:any,all,filter,canFind;
import std.conv:to;
debug {
	import std.stdio;
}

import d.ir.expression;
import d.ir.statement;
import d.ir.symbol;
import d.ir.type;
import d.ir.dscope;

bool[Function] pureTab;

bool isDefinedIn(Scope inner, Scope outer) {
	if (auto _inner = cast(NestedScope)inner) {
		if (_inner.parent) {
			if (_inner.parent is outer) {
				return true;
			} else {
				return isDefinedIn(_inner.parent, outer);
			}
		}
	}

	return false;
}

Expression[] getExpressions(Expression e) {
	if (auto be = cast(BinaryExpression)e) {
		return getExpressions(be.lhs) ~ getExpressions(be.rhs);
	} else if (auto ue = cast(UnaryExpression)e) {
		return getExpressions(ue.expr);
	}
	return [e];
}

Expression[] getExpressions(Statement s) {
	if (auto es = cast(ExpressionStatement) s) {
		return getExpressions(es.expression);
	} else if (auto rs = cast(ReturnStatement) s) {
		return getExpressions(rs.value);
	} else if (auto es = cast(ExpressionStatement) s) {
	}
	return [];
}

Statement[] getStatements(Function f) {
	return getStatements(f.fbody);
}

Statement[] getStatements(Statement s) {
	Statement[] result;

	if (auto be = cast(BlockStatement)s) {
		foreach(stmt;be.statements) {
			result ~= getStatements(stmt);
		}
	} else if (auto fs = cast(ForStatement)s) {
		result ~= getStatements(fs.initialize) ~ getStatements(fs.statement);
	} else {
		result ~= s;
	}

	return result;
}

bool hasSideEffects(d.ir.statement.Statement s) {
	if (auto es = cast(d.ir.statement.ExpressionStatement)s) {
		return hasSideEffects(es.expression); 
	} else {
		return true;
	}

}

bool hasSideEffects(d.ir.expression.Expression e) {
	if (auto be = cast(d.ir.expression.BinaryExpression)e) {
		switch(be.op) with (BinaryOp){
			case Assign :
			case AddAssign :
			case BitwiseAndAssign :
			case BitwiseOrAssign :
			case BitwiseXorAssign :
			case ConcatAssign :
			case DivAssign :
			case LeftShiftAssign :
			case SignedRightShiftAssign :
			case UnsignedRightShiftAssign :
			case LogicalAndAssign :
			case LogicalOrAssign :
			case ModAssign :
			case MulAssign :
			case SubAssign :
			case PowAssign :
				return true;
			default :
				return false;
				
		}
	} else if (auto ue = cast(d.ir.expression.UnaryExpression)e) {
		switch(ue.op) with (UnaryOp) {
			case PreInc :
			case PreDec :
			case PostInc:
			case PostDec:
				return true;
			
			default : 
				return false;
		}
	} else if (cast(NewExpression)e) {
		return true;
	} else if (cast(AssertExpression)e) {
		//DMD suggests this is impure.
		return true;
	} else if (auto ce = cast(CastExpression)e) {
		if (ce.type.dclass) {
			//casts to classes may throw
			//so this is impure
			return true;
		}
	} else if (auto ce = cast(CallExpression)e) {
		return true;
	}

	return false;
}
/// this does check for actual purety
bool isPure(Function f, Function cf = null) {
	if (auto p = f in pureTab) {
		return *p;
	}

	foreach(stmt;f.getStatements.filter!(s => hasSideEffects(s) && s !is null)) {
		foreach(expr;getExpressions(stmt)) {
			//	writeln(typeid(expr));
				if (auto ve = cast (VariableExpression)expr) {
					if (!(ve.var.definedIn is f.dscope) &&
						!isDefinedIn(ve.var.definedIn,cf ? cf.dscope : f.dscope) && 
						!canFind(f.params, ve.var)) {
						pureTab[f] = false;
						return false;
					}
			} else if(auto ce = cast(CallExpression)expr) {
				bool _isPure;
				if (auto me = (cast(MethodExpression)ce.callee)) {
					if (me.method !is f) {
						_isPure = isPure(me.method, f);
					}
				} else if (auto fe = cast(FunctionExpression)ce.callee) {
					if (fe.fun !is f) {
						_isPure = isPure(fe.fun, f);
					}
				} else assert(0,"Unexpected Type: " ~ to!string(typeid(ce.callee)));

				if(!_isPure || any!(e => hasSideEffects(e))(ce.args)) {
					pureTab[f] = false;
					return false;
				}
			}
		}
	}

	pureTab[f] = true;
	return true;
}

bool isCTFECall(d.ir.expression.CallExpression fcall) {
	Function fun = (cast(d.ir.expression.FunctionExpression)fcall.callee).fun;
	bool result = isPure(fun) && fcall.args.all!(a => isCompileTimeExpression(a));
	return result;
}

bool isCompileTimeExpression (d.ir.expression.Expression e) {
	return !!cast(CompileTimeExpression)e;
}