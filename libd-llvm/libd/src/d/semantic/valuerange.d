/**
* Copyright 2014 Stefan Koch
* This file is part of SDC.
* See LICENCE or sdc.d for more details.
*/
module d.semantic.valuerange;

import d.ast.expression;
import d.ir.expression;
import d.ir.type;
import d.semantic.semantic;

alias BinaryExpression = d.ir.expression.BinaryExpression;
alias UnaryExpression = d.ir.expression.UnaryExpression;
alias FieldExpression = d.ir.expression.FieldExpression;

import std.conv;

struct ValueRange {
	long _min = long.max;
	long _max = long.min;
	
	this (long min, long max) {
		this._min = min;
		this._max = max;
	}
	
	bool isInRangeOf(ValueRange that) {
		return (that._max >= _max && that._min <= _min);
	}
	
	static ValueRange from4Numbers (long n1, long n2, long n3, long n4) {
		import std.algorithm : max, min;
		return ValueRange(min(n1, n2, n3, n4), max(n1, n2, n3, n4));
	}
	
	ValueRange opBinary(string op)(ValueRange rhs) {
		import std.algorithm : max, min;
		import std.math : abs;
		static if (op == "+") {
			return ValueRange(_min + rhs._min, _max + rhs._max);
		} else static if (op == "-") {
			return ValueRange(_min - rhs._max, _max - rhs._min);
		} else static if (op == "*") {
			return from4Numbers(_min * rhs._min, _min * rhs._max, _max * rhs._min, _max * rhs._max);
		} else static if (op == "/") { // FIXME this is inacurrate but close enough, for now.
			return from4Numbers(_min / rhs._min, _min / rhs._max, _max / rhs._min, _max / rhs._max);
		} else {
			assert(0,"Operator " ~ to!string(e.op) ~ "is not supported by VRP right now");
		}
	}
	unittest {
		assert(ValueRange(0, 255) - ValueRange(128, 128) == ValueRange(-128, 127));
		assert(ValueRange(3, 3) + ValueRange(-5, 2) == ValueRange(-2, 5));
		assert(ValueRange(2, 4) * ValueRange(-2, 1) == ValueRange(-8, 4));
		assert(ValueRange(4, 8) / ValueRange(-1, 2) == ValueRange(-8, 4));
	}
	
}

struct ValueRangeVisitor {
	import d.location;
	
	SemanticPass pass;
	
	this(SemanticPass pass) {
		this.pass = pass;
	}
	
//	ValueRange visit(QualType qt) {
//		return this.dispatch(qt.type);
//		import d.semantic.identifier;
//		import d.context;
//		
//		auto sr = SymbolResolver!(delegate long (e) {
//			static if(is(typeof(e) : IntegerLiteral!true) || is(typeof(e) : IntegerLiteral!false) || is(typeof(e) : BooleanLiteral)) {
//				return e.value;
//			}
//			assert(0,"Unreachable");
//		})(pass);
//		
//		if (cast(BuiltinType) qt.type) {
//			auto min = sr.resolveInType(loc, qt, BuiltinName!"min");
//			auto max = sr.resolveInType(loc, qt, BuiltinName!"max");
//			return ValueRange(min, max);
//		}
//		assert(0, "ValueRange not supported for " ~ qt.toString(pass.context));
//	}
//	
	ValueRange visit(Expression e) {
		return this.dispatch(e);
	}
	
	ValueRange visit(TypeKind t) {
			if (t == TypeKind.Bool) {
				return ValueRange(bool.min,bool.max);
			} else if (t == TypeKind.Ubyte) {
				return ValueRange(ubyte.min, ubyte.max);
			} else if (t == TypeKind.Ushort) {
				return ValueRange(ushort.min, ushort.max);
			} else if (t == TypeKind.Uint) {
				return ValueRange(uint.min, uint.max);
			} else if (t == TypeKind.Byte) {
				return ValueRange(byte.min, byte.max);
			} else if (t == TypeKind.Short) {
				return ValueRange(short.min, short.max);
			} else if (t == TypeKind.Int) {
				return ValueRange(int.min, int.max);
			} else {
				assert(0, "VRP not suppoted for this expression");
			}
		}
	
	ValueRange visit(VariableExpression e) {
		if (auto bt = cast (BuiltinType)peelAlias(e.type).type) {
			return visit(bt.kind);
		}
		assert(0, "VRP fails");
	}
	
	ValueRange visit(UnaryExpression e) {
		ValueRange rhs = visit(e.expr);
		switch (e.op) with (UnaryOp) {
			case Minus :
				return ValueRange(-rhs._max, -rhs._min);
			default : 
				assert(0,"Operator " ~ to!string(e.op) ~ "is not supported by VRP right now");
		}
		assert(0);
	}
	
	ValueRange visit(BinaryExpression e) {
		ValueRange lhs = visit(e.lhs);
		ValueRange rhs = visit(e.rhs);
		switch (e.op) with (BinaryOp) {
			case Add :
				return lhs + rhs;
			case Sub :
				return lhs - rhs;
			case Assign :
				return rhs;
			default :
				assert(0,"Operator " ~ to!string(e.op) ~ "is not supported by VRP right now");
		}
		assert(0);
	}
	
	ValueRange visit(CastExpression e) {
		return visit(e.expr);
	}
	
	ValueRange visit(FieldExpression e) {
		return visit(e.expr);
	}
	
	ValueRange visit(BooleanLiteral e) {
		return ValueRange(e.value, e.value);
	}
	
	ValueRange visit(CharacterLiteral e) {
		return ValueRange(cast(int) e.value[0], cast(int) e.value[0]);
	}
	
	ValueRange visit(IntegerLiteral!false e) {
		return ValueRange(e.value, e.value);
	}
	
	ValueRange visit(IntegerLiteral!true e) {
		return ValueRange(e.value, e.value);
	}
}

