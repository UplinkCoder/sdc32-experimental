module d.ctfe;
import std.array:array;
import std.algorithm:any,all,filter,canFind;
import std.conv:to;
debug {
	import std.stdio;
}

import d.base.node;
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
/// has to be called on the result of getExpressions!
bool isIllgalImmutable(VariableExpression ve) {
	if (ve.var.type.qualifier == TypeQualifier.Immutable) {
		if (isModifyed(ve)) {
			import d.exception;
			throw new CompileException(ve.parent.location, "Modifying immutable variable");
		}
	}

	return false;
}

bool isModifyed(VariableExpression e) {
	if (auto be = cast(BinaryExpression) e.parent) {
		return isAssign(be.op) && e is be.lhs;
	} else if (auto ue = cast(UnaryExpression) e.parent) {
		return isIncOrDec(ue.op);
	} else {
		return false;
	}
}

Expression[] getExpressions(Expression e, Node p = null) {
	Expression[] result;
	result.reserve(32);

	if (auto be = cast(BinaryExpression) e) {
		result ~= e ~ getExpressions(be.lhs, e) ~ getExpressions(be.rhs, e);
	} else if (auto ue = cast(UnaryExpression) e) {
		result ~= e ~ getExpressions(ue.expr, e);
	} else if (auto te = cast(TernaryExpression) e) {
		result ~= e ~ getExpressions(te.condition, e) ~ getExpressions(te.lhs, e) ~ getExpressions(te.rhs, e);
	} else if (auto ce = cast(CastExpression) e) {
		result ~= e ~ getExpressions(ce.expr, e);
	} else if (auto ce = cast(CallExpression) e) {
		result ~= e ~ getExpressions(ce.callee, e);
		foreach(arg;ce.args) {
			result ~= getExpressions(arg, e);
		}
	} else if (auto se = cast(SliceExpression) e) {
		result ~= e ~ getExpressions(se.sliced, e) ~ getExpressions(se.first, e) ~ getExpressions(se.second, e);
	} else {
		result ~= e;
	}

	if (p) {
		foreach(ref ex;result) {
			ex.parent = cast(Node)(ex.parent ? ex.parent : p); 
		}
	}

	return result;
}

Expression[] getExpressions(Statement s, Node p = null) {
	Expression[] result;
	result.reserve(64);

	foreach(stmt;getStatements(s)) {
		if (stmt !is s)
			result ~= getExpressions(stmt); 
	}

	if (auto es = cast(ExpressionStatement) s) {
		result ~= getExpressions(es.expression, s);
	} else if (auto rs = cast(ReturnStatement) s) {
		result ~= getExpressions(rs.value, s);
	} else if (auto fs = cast(ForStatement) s) {
		result ~= getExpressions(fs.initialize, s) ~ getExpressions(fs.condition, s)
			~ getExpressions(fs.increment, s) ~ getExpressions(fs.statement, s); 
	} else if (auto fs = cast(IfStatement) s) {
		result ~= getExpressions(fs.condition, s) ~ getExpressions(fs.then, s) ~ getExpressions(fs.elseStatement, s); 
	} else if (auto ws = cast(WhileStatement) s) {
		result ~= getExpressions(ws.condition, s) ~ getExpressions(ws.statement, s);
	} else if (auto ds = cast(DoWhileStatement) s) {
		result ~= getExpressions(ds.condition, s) ~ getExpressions(ds.statement, s);
	} else if (auto ss = cast(SwitchStatement) s) {
		result ~= getExpressions(ss.expression, s) ~ getExpressions(ss.statement, s);
	} else if (auto ss = cast(ScopeStatement) s) {
		result ~= getExpressions(ss.statement, s);
	} 

	if (p) {
		foreach(ref se;result) {
			se.parent = cast(Node)(se.parent ? se.parent : p); 
		}
	}
	 
	return result;
}

Statement[] getStatements(Function f) {
	return getStatements(f.fbody);
}

Statement[] getStatements(Statement s, Node p = null) {
	Statement[] result;

	if (auto be = cast(BlockStatement)s) {
		foreach(stmt;be.statements) {
			result ~= getStatements(stmt, s);
		}
	} else {
		result ~= s;
	}

	return result;
}

bool isAssign(BinaryOp op) {
	switch(op) with (BinaryOp){
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
}

bool isIncOrDec(UnaryOp op) {
	switch(op) with (UnaryOp) {
		case PreInc :
		case PreDec :
		case PostInc:
		case PostDec:
			return true;
			
		default : 
			return false;
	}
}

bool hasSideEffects(Expression e) {
	if (auto be = cast(BinaryExpression) e) {
		return isAssign(be.op);
	} else if (auto ue = cast(UnaryExpression) e) {
		return isIncOrDec(ue.op);
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

Symbol getSymbolFromScope(Scope s) {
	auto sscope = cast(SymbolScope)s;
	if (sscope) {
		return sscope.symbol;
	} else {
		return null;
	}
}

Function inFunction(Symbol s) {
	return cast(Function) getSymbolFromScope(s.definedIn);
}

/// this does check for actual purety
bool isPure(Function f, Function cf = null) {
	if (auto p = f in pureTab) {
		return *p;
	}
	if (!f.fbody) { // functions without bodys are considered impure!
		return false;
	}

	foreach(stmt;f.getStatements.filter!(s => s !is null)) {
		foreach(expr;getExpressions(stmt)) {
			if (!isPure(expr, f)) {
				pureTab[f] = false;
				return false;
			}
		}
	}

	pureTab[f] = true;
	return true;
}
/// checks purety of an expression w.r.t Function
/// it takes the result of getExpressions!
bool isPure(Expression e, Function f) {
	if (auto ve = cast (VariableExpression) e) {
		isIllgalImmutable(ve);

		if ((ve.var.definedIn !is f.dscope) &&
			!isDefinedIn(ve.var.definedIn, f.dscope) &&
			ve.var.type.qualifier != TypeQualifier.Immutable) {
			return false;
		}
	} else if(auto ce = cast(CallExpression) e) {
		bool _isPure;
		if (auto me = cast(MethodExpression)ce.callee) {
			if (me.method !is f) {
				_isPure = isPure(me.method, f);
			}
		} else if (auto fe = cast(FunctionExpression)ce.callee) {
			if (fe.fun !is f) {
				_isPure = isPure(fe.fun, f);
			}
		} else assert(0,"Unexpected Type: " ~ to!string(typeid(ce.callee)));
		
	if(!_isPure || any!(e => !isPure(e, f))(ce.args)) {
			return false;
		}
	}

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