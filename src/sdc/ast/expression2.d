module sdc.ast.expression2;

import sdc.location;
import sdc.ast.statement2;

class Expression : Statement {
	this(Location location) {
		super(location);
	}
}

/**
 * Binary Expression types.
 */
enum BinaryOperation {
	None,
	Assign,  // =
	AddAssign,  // +=
	SubAssign,  // -=
	MulAssign,  // *=
	DivAssign,  // /=
	ModAssign,  // %=
	AndAssign,  // &=
	OrAssign,   // |=
	XorAssign,  // ^=
	CatAssign,  // ~=
	ShiftLeftAssign,  // <<=
	SignedShiftRightAssign,  // >>=
	UnsignedShiftRightAssign,  // >>>=
	PowAssign,  // ^^=
	LogicalOr,  // ||
	LogicalAnd,  // &&
	BitwiseOr,  // |
	BitwiseXor,  // ^
	BitwiseAnd,  // &
	Equality,  // == 
	NotEquality,  // !=
	Is,  // is
	NotIs,  // !is
	In,  // in
	NotIn,  // !in
	Less,  // <
	LessEqual,  // <=
	Greater,  // >
	GreaterEqual,  // >=
	Unordered,  // !<>=
	UnorderedEqual,  // !<>
	LessGreater,  // <>
	LessEqualGreater,  // <>=
	UnorderedLessEqual,  // !>
	UnorderedLess, // !>=
	UnorderedGreaterEqual,  // !<
	UnorderedGreater,  // !<=
	LeftShift,  // <<
	SignedRightShift,  // >>
	UnsignedRightShift,  // >>>
	Addition,  // +
	Subtraction,  // -
	Concat,  // ~
	Division,  // /
	Multiplication,  // *
	Modulus,  // %
	Pow,  // ^^
}

class BinaryExpression : Expression {
	private Expression lhs;
	private Expression rhs;
	private BinaryOperation operation;
	
	this(Location location, BinaryOperation operation, Expression lhs, Expression rhs) {
		super(location);
		
		this.lhs = lhs;
		this.rhs = rhs;
		this.operation = operation;
	}
}

/**
 * =
 */
class AssignBinaryExpression : BinaryExpression {
	this(Location location, Expression lhs, Expression rhs) {
		super(location, BinaryOperation.Assign, lhs, rhs);
	}
}

/**
 * +=, -=, *=, /=, %=, &=, |=, ^=, ~=, <<=, >>=, >>>= and ^^=
 */
class OpAssignBinaryExpression(BinaryOperation operation) if(
	operation == BinaryOperation.AddAssign
	|| operation == BinaryOperation.SubAssign
	|| operation == BinaryOperation.MulAssign
	|| operation == BinaryOperation.DivAssign
	|| operation == BinaryOperation.ModAssign
	|| operation == BinaryOperation.AndAssign
	|| operation == BinaryOperation.OrAssign
	|| operation == BinaryOperation.XorAssign
	|| operation == BinaryOperation.CatAssign
	|| operation == BinaryOperation.ShiftLeftAssign
	|| operation == BinaryOperation.ShiftRightAssign
	|| operation == BinaryOperation.UnsignedShiftRightAssign
	|| operation == BinaryOperation.PowAssign
) : BinaryExpression {
	this(Location location, Expression lhs, Expression rhs) {
		super(location, operation, lhs, rhs);
	}
}

/**
 * || and &&
 */
class LogicalBinaryExpression(BinaryOperation operation) if(
	operation == BinaryOperation.LogicalOr
	|| operation == BinaryOperation.LogicalAnd
) : BinaryExpression {
	this(Location location, Expression lhs, Expression rhs) {
		super(location, operation, lhs, rhs);
	}
}

/**
 * &, | and ^
 */
class BitwiseBinaryExpression(BinaryOperation operation) if(
	operation == BinaryOperation.BitwiseOr
	|| operation == BinaryOperation.BitwiseXor
	|| operation == BinaryOperation.BitwiseAnd
) : BinaryExpression {
	this(Location location, Expression lhs, Expression rhs) {
		super(location, operation, lhs, rhs);
	}
}

/**
 * == and !=
 */
class EqualityBinaryExpression(BinaryOperation operation) if(
	operation == BinaryOperation.Equality
	|| operation == BinaryOperation.NotEquality
) : BinaryExpression {
	this(Location location, Expression lhs, Expression rhs) {
		super(location, operation, lhs, rhs);
	}
}

/**
 * is and !is
 */
class IsBinaryExpression(BinaryOperation operation) if(
	operation == BinaryOperation.In
	|| operation == BinaryOperation.NotIn
) : BinaryExpression {
	this(Location location, Expression lhs, Expression rhs) {
		super(location, operation, lhs, rhs);
	}
}

/**
 * in and !in
 */
class IsBinaryExpression(BinaryOperation operation) if(
	operation == BinaryOperation.Is
	|| operation == BinaryOperation.NotIs
) : BinaryExpression {
	this(Location location, Expression lhs, Expression rhs) {
		super(location, operation, lhs, rhs);
	}
}

/**
 * <, <=, >, >=, <>, <>=, !<, !<=, !>, !>=, !<> and !<>=
 */
class ComparaisonBinaryExpression(BinaryOperation operation) if(
	operation == BinaryOperation.Less
	|| operation == BinaryOperation.LessEqual
	|| operation == BinaryOperation.Greater
	|| operation == BinaryOperation.GreaterEqual
	|| operation == BinaryOperation.Unordered
	|| operation == BinaryOperation.UnorderedEqual
	|| operation == BinaryOperation.LessGreater
	|| operation == BinaryOperation.LessEqualGreater
	|| operation == BinaryOperation.UnorderedLessEqual
	|| operation == BinaryOperation.UnorderedLess
	|| operation == BinaryOperation.UnorderedGreaterEqual
	|| operation == BinaryOperation.UnorderedGreater
) : BinaryExpression {
	this(Location location, Expression lhs, Expression rhs) {
		super(location, operation, lhs, rhs);
	}
}

/**
 * <<, >> and >>>
 */
class ShiftBinaryExpression(BinaryOperation operation) if(
	operation == BinaryOperation.LeftShift
	|| operation == BinaryOperation.SignedRightShift
	|| operation == BinaryOperation.UnsignedRightShift
) : BinaryExpression {
	this(Location location, Expression lhs, Expression rhs) {
		super(location, operation, lhs, rhs);
	}
}

/**
 * Binary +, -, ~, *, /, %, and ^^
 */
class OperationBinaryExpression(BinaryOperation operation) if(
	operation == BinaryOperation.Addition
	|| operation == BinaryOperation.Subtraction
	|| operation == BinaryOperation.Concat
	|| operation == BinaryOperation.Multiplication
	|| operation == BinaryOperation.Division
	|| operation == BinaryOperation.Modulus
	|| operation == BinaryOperation.Pow
) : BinaryExpression {
	this(Location location, Expression lhs, Expression rhs) {
		super(location, operation, lhs, rhs);
	}
}

/**
 * Unary Expression types.
 */
enum UnaryPrefix
{
	None,
	AddressOf,  // &
	PrefixInc,  // ++
	PrefixDec,  // --
	Dereference,  // *
	UnaryPlus,  // +
	UnaryMinus,  // -
	LogicalNot,  // !
	BitwiseNot,  // ~
	Cast,  // cast (type) unaryExpr
	New,
}


class UnaryExpression : Expression {
	private Expression expression;
	private UnaryPrefix operation;
	
	this(Location location, UnaryPrefix operation, Expression expression) {
		super(location);
		
		this.expression = expression;
		this.operation = operation;
	}
}

/**
 * Unary &
 */
class AddressOfUnaryExpression : UnaryExpression {
	this(Location location, Expression expression) {
		super(location, UnaryPrefix.AddressOf, expression);
	}
}

/**
 * ++ and --
 */
class OpAssignUnaryExpression(UnaryPrefix operation) if(
	operation == UnaryPrefix.PrefixInc
	|| operation == UnaryPrefix.PrefixDec
) : UnaryExpression {
	this(Location location, Expression expression) {
		super(location, operation, expression);
	}
}

/**
 * Unary *
 */
class DereferenceUnaryExpression : UnaryExpression {
	this(Location location, Expression expression) {
		super(location, UnaryPrefix.Dereference, expression);
	}
}

/**
 * Unary + and -
 */
class OperationUnaryExpression(UnaryPrefix operation) if(
	operation == UnaryPrefix.UnaryPlus
	|| operation == UnaryPrefix.UnaryMinus
) : UnaryExpression {
	this(Location location, Expression expression) {
		super(location, operation, expression);
	}
}

/**
 * !
 */
class NotUnaryExpression : UnaryExpression {
	this(Location location, Expression expression) {
		super(location, UnaryPrefix.LogicalNot, expression);
	}
}

/**
 * Unary ~
 */
class CompelementExpression : UnaryExpression {
	this(Location location, Expression expression) {
		super(location, UnaryPrefix.BitwiseNot, expression);
	}
}
