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
alias FieldExpression = d.ir.expression.FieldExpression;

struct ValueRange {
	long _min = long.max;
	long _max = long.min;

	bool isInRangeOf(ValueRange that) {
		return (that._max >= _max && that._min <= _min);
	}

	bool isInRangeOf(TypeKind k) {
		return isInRangeOf(rangeOf(k));
	}

	static ValueRange fromNumbers(long[] nums) {
		import std.algorithm : max, min, reduce;
		return ValueRange(reduce!min(nums), reduce!max(nums));
	}

	ValueRange opBinary(string op)(ValueRange rhs) {
		import std.algorithm : max, min;
		import std.math : abs;
		static if (op == "+") {
			return ValueRange(_min + rhs._min, _max + rhs._max);
		} else static if (op == "-") {
			return ValueRange(_min - rhs._max, _max - rhs._min);
		} else static if (op == "*") {
			return fromNumbers([_min * rhs._min, _min * rhs._max, _max * rhs._max]);
		} else static if (op == "/") {
			return fromNumbers([_min / rhs._min, _min / rhs._max, _max / rhs._min, ._max / rhs.max]);
		} else static if (op == "%") {
			auto r_max = max(abs(rhs._min), rhs.max) - 1;
			return ValueRange(min(_min, -r_max), max(_max, r_max));
		} else
			return ValueRange.init;
	}
	unittest {
		import std.stdio;
		assert(ValueRange(0, 255) - ValueRange(128, 128) == ValueRange(-128, 127));
		assert(ValueRange(3, 3) + ValueRange(-5, 2) == ValueRange(-2, 5));
		assert(ValueRange(-7, 3) % ValueRange(-5, 2) == ValueRange(-4, 3));
	}

	ValueRange merge(ValueRange rhs) {
		import std.algorithm : max, min;
		return ValueRange(min(_min, rhs._min), max(_max, rhs._max));
	}

	static ValueRange rangeOf(TypeKind t) {
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
		} else
			return ValueRange.init;
	}
}

struct ValueRangeVisitor {
	SemanticPass pass;

	this(SemanticPass pass)
	{
		this.pass = pass;
	}

	ValueRange visit(Expression e) {
		import d.exception;
		return this.dispatch!(function ValueRange(Expression e) {
	      return ValueRange.init;
		})(e);
	}

	ValueRange visit(VariableExpression e) {
		if (auto bType = cast(BuiltinType) peelAlias(e.type).type) {
			return ValueRange.rangeOf(bType.kind);
		} else {
			return ValueRange.init;
		}
	}

	ValueRange visit(BinaryExpression e) {
		ValueRange lhs = visit(e.lhs);
		ValueRange rhs = visit(e.rhs);
		switch (e.op)
			with (BinaryOp) {
			case AddAssign :
			case Add :
				return lhs + rhs;
			case SubAssign :
			case Sub :
				return lhs - rhs;
			case Assign :
				return rhs;
			default :
				return ValueRange.init;
			}
	}

	ValueRange visit(CastExpression e) {
		return visit(e.expr);
	}

	ValueRange visit(FieldExpression e) {
		return visit(e.expr);
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

	unittest {
		import d.location;
		auto il = new IntegerLiteral!false(Location.init, 1, TypeKind.Int);
		assert(ValueRangeVisitor().visit(il).isInRangeOf(TypeKind.Byte));
		assert(ValueRangeVisitor().visit(il).isInRangeOf(TypeKind.Bool));
		assert(ValueRangeVisitor().visit(new BinaryExpression(Location.init, getBuiltin(TypeKind.Int), BinaryOp.Sub, new IntegerLiteral!false(Location.init, 255, TypeKind.Uint), new IntegerLiteral!false(Location.init, 128, TypeKind.Int))).isInRangeOf(TypeKind.Byte));
		assert(ValueRange.rangeOf(TypeKind.Ubyte).isInRangeOf(TypeKind.Short));
		assert(!(ValueRange.rangeOf(TypeKind.Short).isInRangeOf(TypeKind.Byte)));
	}
}

