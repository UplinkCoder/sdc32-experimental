module d.ast.expression;

import d.ast.declaration;
import d.ast.identifier;
import d.ast.statement;
import d.ast.type;

import d.context.name;
import d.common.node;

abstract class AstExpression : Node {
	this(Location location) {
		super(location);
	}
	
	string toString(const Context) const {
		assert(0, "toString not implement for " ~ typeid(this).toString());
	}
}

final:
/**
 * Conditional expression of type ?:
 */
class TernaryExpression(E) : E if (is(E: AstExpression)) {
	E condition;
	E lhs;
	E rhs;
	
	this(U...)(Location location, U args, E condition, E lhs, E rhs) {
		super(location, args);
		
		this.condition = condition;
		this.lhs = lhs;
		this.rhs = rhs;
	}
	
	override string toString(const Context c) const {
		return condition.toString(c)
			~ " ? " ~ lhs.toString(c)
			~ " : " ~ rhs.toString(c);
	}
}

alias AstTernaryExpression = TernaryExpression!AstExpression;

/**
 * Binary Expressions.
 */
enum AstBinaryOp {
	Comma,
	Assign,
	Add,
	Sub,
	Mul,
	Div,
	Mod,
	Pow,
	BitwiseOr,
	BitwiseAnd,
	BitwiseXor,
	LeftShift,
	SignedRightShift,
	UnsignedRightShift,
	LogicalOr,
	LogicalAnd,
	Concat,
	AddAssign,
	SubAssign,
	MulAssign,
	DivAssign,
	ModAssign,
	PowAssign,
	BitwiseOrAssign,
	BitwiseAndAssign,
	BitwiseXorAssign,
	LeftShiftAssign,
	SignedRightShiftAssign,
	UnsignedRightShiftAssign,
	LogicalOrAssign,
	LogicalAndAssign,
	ConcatAssign,
	Equal,
	NotEqual,
	Identical,
	NotIdentical,
	In,
	NotIn,
	Greater,
	GreaterEqual,
	Less,
	LessEqual,
	
	// Weird float operators
	LessGreater,
	LessEqualGreater,
	UnorderedLess,
	UnorderedLessEqual,
	UnorderedGreater,
	UnorderedGreaterEqual,
	Unordered,
	UnorderedEqual,
}

bool isAssign(AstBinaryOp op) {
	return op >= AstBinaryOp.AddAssign && op <= AstBinaryOp.ConcatAssign;
}

unittest {
	enum Assign = "Assign";
	bool isAssignStupid(AstBinaryOp op) {
		import std.conv;
		auto s = op.to!string();
		if (s.length <= Assign.length) {
			return false;
		}
		
		return s[$ - Assign.length .. $] == Assign;
	}
	
	import std.traits;
	foreach(op; EnumMembers!AstBinaryOp) {
		import std.conv;
		assert(op.isAssign() == isAssignStupid(op), op.to!string());
	}
}

AstBinaryOp getBaseOp(AstBinaryOp op) in {
	assert(isAssign(op));
} body {
	return op + AstBinaryOp.Add - AstBinaryOp.AddAssign;
}

unittest {
	enum Assign = "Assign";
	
	import std.traits;
	foreach(op; EnumMembers!AstBinaryOp) {
		if (!op.isAssign()) {
			continue;
		}
		
		import std.conv;
		auto b0 = op.to!string()[0 .. $ - Assign.length];
		auto b1 = op.getBaseOp().to!string();
		assert(b0 == b1);
	}
}

class AstBinaryExpression : AstExpression {
	AstBinaryOp op;
	
	AstExpression lhs;
	AstExpression rhs;
	
	this(
		Location location,
		AstBinaryOp op,
		AstExpression lhs,
		AstExpression rhs,
	) {
		super(location);
		
		this.op = op;
		this.lhs = lhs;
		this.rhs = rhs;
	}
	
	override string toString(const Context c) const {
		import std.conv;
		return lhs.toString(c) ~ " " ~ to!string(op) ~ " " ~ rhs.toString(c);
	}
}

/**
 * Unary Expression types.
 */
enum UnaryOp {
	AddressOf,
	Dereference,
	PreInc,
	PreDec,
	PostInc,
	PostDec,
	Plus,
	Minus,
	Complement,
	Not,
}

string unarizeString(string s, UnaryOp op) {
	final switch(op) with(UnaryOp) {
		case AddressOf :
			return "&" ~ s;
		
		case Dereference :
			return "*" ~ s;
		
		case PreInc :
			return "++" ~ s;
		
		case PreDec :
			return "--" ~ s;
		
		case PostInc :
			return s ~ "++";
		
		case PostDec :
			return s ~ "--";
		
		case Plus :
			return "+" ~ s;
		
		case Minus :
			return "-" ~ s;
		
		case Not :
			return "!" ~ s;
		
		case Complement :
			return "~" ~ s;
	}
}

class AstUnaryExpression : AstExpression {
	AstExpression expr;
	UnaryOp op;
	
	this(Location location, UnaryOp op, AstExpression expr) {
		super(location);
		
		this.expr = expr;
		this.op = op;
	}
	
	invariant() {
		assert(expr);
	}
	
	override string toString(const Context c) const {
		return unarizeString(expr.toString(c), op);
	}
}

class AstCastExpression : AstExpression {
	AstType type;
	AstExpression expr;
	
	this(Location location, AstType type, AstExpression expr) {
		super(location);
		
		this.type = type;
		this.expr = expr;
	}
	
	override string toString(const Context c) const {
		return "cast(" ~ type.toString(c) ~ ") " ~ expr.toString(c);
	}
}

/**
 * Function call
 */
class AstCallExpression : AstExpression {
	AstExpression callee;
	AstExpression[] args;
	
	this(Location location, AstExpression callee, AstExpression[] args) {
		super(location);
		
		this.callee = callee;
		this.args = args;
	}
	
	override string toString(const Context c) const {
		import std.algorithm, std.range;
		auto aa = args.map!(a => a.toString(c)).join(", ");
		return callee.toString(c) ~ "(" ~ aa ~ ")";
	}
}

/**
 * Indetifier calls.
 */
class IdentifierCallExpression : AstExpression {
	Identifier callee;
	AstExpression[] args;
	
	this(Location location, Identifier callee, AstExpression[] args) {
		super(location);
		
		this.callee = callee;
		this.args = args;
	}
	
	override string toString(const Context c) const {
		import std.algorithm, std.range;
		auto aa = args.map!(a => a.toString(c)).join(", ");
		return callee.toString(c) ~ "(" ~ aa ~ ")";
	}
}

/**
 * Index expression : indexed[arguments]
 */
class AstIndexExpression : AstExpression {
	AstExpression indexed;
	AstExpression[] arguments;
	
	this(Location location, AstExpression indexed, AstExpression[] arguments) {
		super(location);
		
		this.indexed = indexed;
		this.arguments = arguments;
	}
}

/**
 * Slice expression : [first .. second]
 */
class AstSliceExpression : AstExpression {
	AstExpression sliced;
	
	AstExpression[] first;
	AstExpression[] second;
	
	this(
		Location location,
		AstExpression sliced,
		AstExpression[] first,
		AstExpression[] second,
	) {
		super(location);
		
		this.sliced = sliced;
		this.first = first;
		this.second = second;
	}
}

/**
 * Parenthese expression.
 */
class ParenExpression : AstExpression {
	AstExpression expr;
	
	this(Location location, AstExpression expr) {
		super(location);
		
		this.expr = expr;
	}
}

/**
 * Identifier expression
 */
class IdentifierExpression : AstExpression {
	Identifier identifier;
	
	this(Identifier identifier) {
		super(identifier.location);
		
		this.identifier = identifier;
	}
	
	override string toString(const Context c) const {
		return identifier.toString(c);
	}
}

/**
 * new
 */
class NewExpression : AstExpression {
	AstType type;
	AstExpression[] args;
	
	this(Location location, AstType type, AstExpression[] args) {
		super(location);
		
		this.type = type;
		this.args = args;
	}
	
	override string toString(const Context c) const {
		import std.algorithm, std.range;
		auto aa = args.map!(a => a.toString(c)).join(", ");
		return "new " ~ type.toString(c) ~ "(" ~ aa ~ ")";
	}
}

alias AstNewExpression = NewExpression;

/**
 * This
 */
class ThisExpression : AstExpression {
	this(Location location) {
		super(location);
	}
	
	override string toString(const Context) const {
		return "this";
	}
}

/**
 * Array literal
 */
class ArrayLiteral(T) : T if(is(T: AstExpression)) {
	T[] values;
	
	this(Location location, T[] values) {
		super(location);
		
		this.values = values;
	}
	
	override string toString(const Context c) const {
		import std.algorithm, std.range;
		return "[" ~ values.map!(v => v.toString(c)).join(", ") ~ "]";
	}
}

alias AstArrayLiteral = ArrayLiteral!AstExpression;

/**
 * __FILE__ literal
 */
class __File__Literal : AstExpression {
	this(Location location) {
		super(location);
	}
}

/**
 * __LINE__ literal
 */
class __Line__Literal : AstExpression {
	this(Location location) {
		super(location);
	}
}

/**
 * Delegate literal
 */
class DelegateLiteral : AstExpression {
	ParamDecl[] params;
	bool isVariadic;
	AstBlockStatement fbody;
	
	this(
		Location location,
		ParamDecl[] params,
		bool isVariadic,
		AstBlockStatement fbody,
	) {
		super(location);
		
		this.params = params;
		this.isVariadic = isVariadic;
		this.fbody = fbody;
	}
	
	this(AstBlockStatement fbody) {
		this(fbody.location, [], false, fbody);
	}
}

/**
 * Lambda expressions
 */
class Lambda : AstExpression {
	ParamDecl[] params;
	AstExpression value;
	
	this(Location location, ParamDecl[] params, AstExpression value) {
		super(location);
		
		this.params = params;
		this.value = value;
	}
}

/**
 * $
 */
class DollarExpression : AstExpression {
	this(Location location) {
		super(location);
	}
}

/**
 * flavour of isExpression.
 */
enum IsKind {
	Basic,
	ConvertCompare,
	ExactCompare,
	Kind,
	Qualifier,
}
/**
 * is expression.
 */
class IsExpression : AstExpression {
	AstType tested;
	IsKind isKind;

	import d.ir.type:TypeKind;
	union {
		AstType against;
		TypeKind typeKind;
		TypeQualifier qualifier;
	}

	this(Location location, AstType tested) {
		super(location);
		
		this.tested = tested;
		this.isKind = IsKind.Basic;
	}


	this(Location location, AstType tested, bool isExact, AstType against) {
		super(location);

		this.tested = tested;
		if (isExact) {
			this.isKind = isKind.ExactCompare;
		} else {
			this.isKind = IsKind.ConvertCompare;
		}
		this.against = against;
	}

	this(Location location, AstType tested, TypeKind typeKind) {
		super(location);
		
		this.tested = tested;
		this.isKind = isKind.Kind;
		this.typeKind = typeKind;
	}

	this(Location location, AstType tested, TypeQualifier qualifier) {
		super(location);
		
		this.tested = tested;
		this.isKind = IsKind.Qualifier;
		this.qualifier = qualifier;
	}

	override string toString(const Context c) const {
		import std.conv:to;
		import std.string:toLower;
		string result = "is(" ~ tested.toString(c);

		final switch (isKind) with (IsKind) {
		case ExactCompare :
			result ~= " == " ~ against.toString(c);
			goto case Basic;
		case ConvertCompare :
			result ~= " : " ~ against.toString(c);
			goto case Basic;
		case Kind :
			result ~= " == " ~ to!string(typeKind).toLower;
			goto case Basic;
		case Qualifier :
			result ~= " == " ~ to!string(qualifier).toLower;
			goto case Basic;
		case Basic :
			result ~= ")";
		}

		return result;
	}
}

/**
 * typeid(expression) expression.
 */
class AstTypeidExpression : AstExpression {
	AstExpression argument;
	
	this(Location location, AstExpression argument) {
		super(location);
		
		this.argument = argument;
	}
}

/**
 * typeid(type) expression.
 */
class StaticTypeidExpression(T, E) : E if(is(E: AstExpression)) {
	T argument;
	
	this(U...)(Location location, U args, T argument) {
		super(location, args);
		
		this.argument = argument;
	}
	
	override string toString(const Context c) const {
		return "typeid(" ~ argument.toString(c) ~ ")";
	}
}

alias AstStaticTypeidExpression =
	StaticTypeidExpression!(AstType, AstExpression);

/**
 * ambiguous typeid expression.
 */
class IdentifierTypeidExpression : AstExpression {
	Identifier argument;
	
	this(Location location, Identifier argument) {
		super(location);
		
		this.argument = argument;
	}
}

/**
 * Used for type identifier = void;
 */
class AstVoidInitializer : AstExpression {
	this(Location location) {
		super(location);
	}
	
	override string toString(const Context) const {
		return "void";
	}
}
