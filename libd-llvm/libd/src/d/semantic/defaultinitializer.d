module d.semantic.defaultinitializer;

import d.semantic.semantic;

import d.ir.expression;
import d.ir.type;

import d.location;

struct DefaultInitializerVisitor {
	private SemanticPass pass;
	alias pass this;
	
	this(SemanticPass pass) {
		this.pass = pass;
	}
	
	Expression visit(Location location, QualType t) {
		auto e = this.dispatch!((t) {
			return pass.raiseCondition!Expression(location, "Type " ~ typeid(t).toString() ~ " has no initializer.");
		})(location, peelAlias(t).type);
		
		e.type.qualifier = t.qualifier;
		return e;
	}
	
	Expression visit(Location location, BuiltinType t) {
		final switch(t.kind) with(TypeKind) {
			case None :
				assert(0,"none shall not be!");
			case Void :
				assert(0, "Void initializer not Implemented");
			
			case Bool :
				return new BooleanLiteral(location, false);
			
			case Char :
			case Wchar :
			case Dchar :
				return new CharacterLiteral(location, [char.init], t.kind);
			
			case Ubyte :
			case Ushort :
			case Uint :
			case Ulong :
			case Ucent :
				return new IntegerLiteral!false(location, 0, t.kind);
			
			case Byte :
			case Short :
			case Int :
			case Long :
			case Cent :
				return new IntegerLiteral!true(location, 0, t.kind);
			
			case Float :
			case Double :
			case Real :
				return new FloatLiteral(location, float.nan, t.kind);
			
			case Null :
				return new NullLiteral(location);
		}
	}
	
	Expression visit(Location location, PointerType t) {
		return new NullLiteral(location, QualType(t));
	}
	
	Expression visit(Location location, SliceType t) {
		// Convoluted way to create the array due to compiler limitations.
		Expression[] init = [new NullLiteral(location, t.sliced)];
		init ~= new IntegerLiteral!false(location, 0, TypeKind.Uint);
		
		auto ret = new TupleExpression(location, init);
		ret.type = QualType(t);
		
		return ret;
	}
	
	Expression visit(Location location, ArrayType t) {
		return new VoidInitializer(location, QualType(t));
	}
	
	Expression visit(Location location, StructType t) {
		auto s = t.dstruct;
		scheduler.require(s, Step.Populated);
		
		import d.ir.symbol, d.context;
		auto init = cast(Variable) s.dscope.resolve(BuiltinName!"init");
		
		// XXX: Create a new node ?
		return init.value;
	}
	
	Expression visit(Location location, ClassType t) {
		return new NullLiteral(location, QualType(t));
	}
	
	Expression visit(Location location, FunctionType t) {
		return new NullLiteral(location, QualType(t));
	}
}

