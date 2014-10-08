module d.ir.expression;

import d.ast.base;
import d.ast.expression;

import d.ir.symbol;
import d.ir.type;

abstract class Expression : AstExpression {
	QualType type;
	
	this(Location location, QualType type) {
		super(location);
		
		this.type = type;
	}
	
	@property
	bool isLvalue() const {
		return false;
	}
}

alias TernaryExpression = d.ast.expression.TernaryExpression!Expression;
alias BinaryExpression = d.ast.expression.BinaryExpression!Expression;
alias UnaryExpression = d.ast.expression.UnaryExpression!Expression;
alias CallExpression = d.ast.expression.CallExpression!Expression;
alias IndexExpression = d.ast.expression.IndexExpression!Expression;
alias SliceExpression = d.ast.expression.SliceExpression!Expression;
alias AssertExpression = d.ast.expression.AssertExpression!Expression;
alias StaticTypeidExpression = d.ast.expression.StaticTypeidExpression!(QualType, Expression);

alias BinaryOp = d.ast.expression.BinaryOp;
alias UnaryOp = d.ast.expression.UnaryOp;

/**
 * Any expression that have a value known at compile time.
 */
abstract class CompileTimeExpression : Expression {
	this(Location location, QualType type) {
		super(location, type);
	}
}

final:
/**
 * An Error occured but an Expression is expected.
 * Useful for speculative compilation.
 */
class ErrorExpression : CompileTimeExpression {
	string message;
	
	this(Location location, string message) {
		super(location, getBuiltin(TypeKind.None));
		
		this.message = message;
	}
}

/**
 * Expression that can in fact be several expressions.
 * A good example is IdentifierExpression that resolve as overloaded functions.
 */
class PolysemousExpression : Expression {
	Expression[] expressions;
	
	this(Location location, Expression[] expressions) {
		super(location, getBuiltin(TypeKind.None));
		
		this.expressions = expressions;
	}
	
	invariant() {
		assert(expressions.length > 1);
	}
}

/**
 * This
 */
class ThisExpression : Expression {
	this(Location location) {
		super(location, getBuiltin(TypeKind.None));
	}
	
	this(Location location, QualType type) {
		super(location, type);
	}
	
	override string toString(Context) const {
		return "this";
	}
	
	@property
	override bool isLvalue() const {
		return !(cast(ClassType) type.type);
	}
}

/**
 * Super
 */
class SuperExpression : Expression {
	this(Location location) {
		super(location, getBuiltin(TypeKind.None));
	}
	
	this(Location location, QualType type) {
		super(location, type);
	}
	
	override string toString(Context) const {
		return "super";
	}
	
	@property
	override bool isLvalue() const {
		return true;
	}
}

/**
 * Context
 */
class ContextExpression : Expression {
	this(Location location, ContextType type) {
		super(location, QualType(type));
	}
	
	override string toString(Context) const {
		return "__ctx";
	}
	
	@property
	override bool isLvalue() const {
		return true;
	}
}

/**
 * Virtual table
 * XXX: This is highly dubious. Explore the alternatives and get rid of that.
 */
class VtblExpression : Expression {
	Class dclass;
	
	this(Location location, Class dclass) {
		super(location, QualType(new PointerType(getBuiltin(TypeKind.Void))));
		
		this.dclass = dclass;
	}
	
	override string toString(Context c) const {
		return dclass.toString(c) ~ ".__vtbl";
	}
}

/**
 * Boolean literal
 */
class BooleanLiteral : CompileTimeExpression {
	bool value;
	
	this(Location location, bool value) {
		super(location, getBuiltin(TypeKind.Bool));
		
		this.value = value;
	}
	
	override string toString(Context) const {
		return value?"true":"false";
	}
}

/**
 * Integer literal
 */
class IntegerLiteral(bool isSigned) : CompileTimeExpression {
	static if(isSigned) {
		alias long ValueType;
	} else {
		alias ulong ValueType;
	}
	
	ValueType value;
	
	this(Location location, ValueType value, TypeKind kind) in {
		assert(isIntegral(kind));
	} body {
		super(location, getBuiltin(kind));
		
		this.value = value;
	}
	
	override string toString(Context) const {
		import std.conv;
		return to!string(value);
	}
}

/**
 * Float literal
 */
class FloatLiteral : CompileTimeExpression {
	double value;
	
	this(Location location, double value, TypeKind kind) in {
		assert(isFloat(kind));
	} body {
		super(location, getBuiltin(kind));
		
		this.value = value;
	}
}

/**
 * Character literal
 */
class CharacterLiteral : CompileTimeExpression {
	string value;
	
	this(Location location, string value, TypeKind kind) in {
		assert(isChar(kind));
	} body {
		super(location, getBuiltin(kind));
		
		this.value = value;
	}
	
	override string toString(Context) const {
		return "'" ~ value ~ "'";
	}
	
	invariant() {
		assert(value.length > 0);
	}
}

/**
 * String literal
 */
class StringLiteral : CompileTimeExpression {
	string value;
	
	this(Location location, string value) {
		auto c = getBuiltin(TypeKind.Char);
		c.qualifier = TypeQualifier.Immutable;
		
		super(location, QualType(new SliceType(c)));
		
		this.value = value;
	}
	
	override string toString(Context) const {
		return "\"" ~ value ~ "\"";
	}
}

/**
 * Null literal
 */
class NullLiteral : CompileTimeExpression {
	this(Location location) {
		this(location, getBuiltin(TypeKind.Null));
	}
	
	this(Location location, QualType t) {
		super(location, t);
	}
	
	override string toString(Context) const {
		return "null";
	}
}

/**
 * Cast expressions
 */
enum CastKind {
	Invalid,
	Down,
	IntegralToBool,
	Trunc,
	Pad,
	Bit,
	Qual,
	Exact,
}

class CastExpression : Expression {
	Expression expr;
	
	CastKind kind;
	
	this(Location location, CastKind kind, QualType type, Expression expr) {
		super(location, type);
		
		this.kind = kind;
		this.expr = expr;
	}
	
	override string toString(Context ctx) const {
		return "cast(" ~ type.toString(ctx) ~ ") " ~ expr.toString(ctx);
	}
	
	@property
	override bool isLvalue() const {
		final switch(kind) with(CastKind) {
			case Invalid :
			case Down :
			case IntegralToBool :
			case Trunc :
			case Pad :
				return false;
			
			case Bit :
			case Qual :
			case Exact :
				return expr.isLvalue;
		}
	}
}

/**
 * new
 */
class NewExpression : Expression {
	Expression dinit;
	Expression ctor;
	Expression[] args;
	
	this(Location location, QualType type, Expression dinit, Expression ctor, Expression[] args) {
		super(location, type);
		
		this.dinit = dinit;
		this.ctor = ctor;
		this.args = args;
	}
	
	override string toString(Context ctx) const {
		import std.algorithm, std.range;
		return "new " ~ type.toString(ctx) ~ "(" ~ args.map!(a => a.toString(ctx)).join(", ") ~ ")";
	}
}

/**
 * IdentifierExpression that as been resolved as a Variable.
 */
class VariableExpression : Expression {
	Variable var;
	
	this(Location location, Variable var) {
		super(location, var.type);
		
		this.var = var;
	}
	
	override string toString(Context ctx) const {
		return var.name.toString(ctx);
	}
	
	@property
	override bool isLvalue() const {
		return var.storage != Storage.Enum;
	}
}

/**
 * Field access.
 */
class FieldExpression : Expression {
	Expression expr;
	Field field;
	
	this(Location location, Expression expr, Field field) {
		super(location, field.type);
		
		this.expr = expr;
		this.field = field;
	}
	
	override string toString(Context ctx) const {
		return expr.toString(ctx) ~ "." ~ field.name.toString(ctx);
	}
	
	@property
	override bool isLvalue() const {
		return (cast(ClassType) expr.type.type) || expr.isLvalue;
	}
}

/**
 * IdentifierExpression that as been resolved as a Function.
 * XXX: Deserve to be merged with VariableExpression somehow.
 */
class FunctionExpression : Expression {
	Function fun;
	
	this(Location location, Function fun) {
		super(location, QualType(fun.type));
		
		this.fun = fun;
	}
	
	override string toString(Context ctx) const {
		return fun.name.toString(ctx);
	}
}

/**
 * Methods resolved on expressions.
 */
class MethodExpression : Expression {
	Expression expr;
	Function method;
	
	this(Location location, Expression expr, Function method) {
		super(location, QualType(new DelegateType(method.type)));
		
		this.expr = expr;
		this.method = method;
	}
	
	override string toString(Context ctx) const {
		return expr.toString(ctx) ~ "." ~ method.name.toString(ctx);
	}
}

/**
 * IdentifierExpression that as been resolved as a Parameter.
 * XXX: Deserve to be merged with VariableExpression somehow.
 */
class ParameterExpression : Expression {
	Parameter param;
	
	this(Location location, Parameter param) {
		super(location, QualType(param.type.type, param.type.qualifier));
		
		this.param = param;
	}
	
	override string toString(Context ctx) const {
		return param.name.toString(ctx);
	}
	
	@property
	override bool isLvalue() const {
		return true;
	}
}

/**
 * For classes, typeid is computed at runtime.
 */
class DynamicTypeidExpression : Expression {
	Expression argument;
	
	this(Location location, QualType type, Expression argument) {
		super(location, type);
		
		this.argument = argument;
	}
	
	override string toString(Context ctx) const {
		return "typeid(" ~ argument.toString(ctx) ~ ")";
	}
}

/**
 * Used for type identifier = void;
 */
class VoidInitializer : CompileTimeExpression {
	this(Location location) {
		super(location, getBuiltin(TypeKind.None));
	}
	
	this(Location location, QualType type) {
		super(location, type);
	}
	
	override string toString(Context) const {
		return "void";
	}
}

/**
 * tuples. Also used for struct initialization.
 */
template TupleExpressionImpl(bool isCompileTime = false) {
	static if(isCompileTime) {
		alias E = CompileTimeExpression;
	} else {
		alias E = Expression;
	}
	
	class TupleExpressionImpl : E {
		E[] values;
		
		this(Location location, QualType t, E[] values) {
			// Implement type tuples.
			super(location, t);
		
			this.values = values;
		}
	}
}

// XXX: required as long as 0 argument instanciation is not possible.
alias TupleExpression = TupleExpressionImpl!false;
alias CompileTimeTupleExpression = TupleExpressionImpl!true;

