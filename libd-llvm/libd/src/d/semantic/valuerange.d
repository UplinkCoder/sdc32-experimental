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
		static if (op == "+") {
			return ValueRange(_min + rhs._min, _max + rhs._max);
		} else static if (op == "-") {
			return ValueRange(_min - rhs._max, _max - rhs._min);
		} else {
			assert(0,"Operator " ~ to!string(e.op) ~ " is not supported by VRP right now");
		}
	}

	unittest {
		assert(ValueRange(0, 255) - ValueRange(128, 128) == ValueRange(-128, 127));
		assert(ValueRange(3, 3) + ValueRange(-5, 2) == ValueRange(-2, 5));
	}
	
}

struct ValueRangeVisitor {
	import d.location;
	
	SemanticPass pass;
	
	this(SemanticPass pass) {
		this.pass = pass;
	}

	ValueRange visit(BuiltinType bt) {
		return ValueRange(getMin(bt), getMax(bt));
	}
	
	ValueRange visit(Expression e) {
		return this.dispatch(e);
	}
	
	ValueRange visit(TypeKind k) {
		return visit(new BuiltinType(k));
	}
	
	ValueRange visit(VariableExpression e) {
		return this.dispatch(peelAlias(e.type).type);
	}
	
	ValueRange visit(UnaryExpression e) {
		ValueRange rhs = visit(e.expr);
		switch (e.op) with (UnaryOp) {
			case Minus :
				return ValueRange(-rhs._max, -rhs._min);
			default : 
				assert(0, "Operator " ~ to!string(e.op) ~ " is not supported by VRP right now");
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
				assert(0, "Operator " ~ to!string(e.op) ~ " is not supported by VRP right now");

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

