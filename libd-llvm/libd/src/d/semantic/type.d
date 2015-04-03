module d.semantic.type;

import d.semantic.semantic;

import d.ast.identifier;
import d.ast.type;

import d.ir.type;

// XXX: module level for UFCS.
import std.algorithm, std.array;

struct TypeVisitor {
	private SemanticPass pass;
	alias pass this;
	
	private TypeQualifier qualifier;
	
	this(SemanticPass pass, TypeQualifier qualifier = TypeQualifier.Mutable) {
		this.pass = pass;
		this.qualifier = qualifier;
	}
	
	import d.ast.declaration;
	TypeVisitor withStorageClass(StorageClass stc) {
		return TypeVisitor(
			pass,
			stc.hasQualifier
				? qualifier.add(stc.qualifier)
				: qualifier,
		);
	}
	
	Type visit(AstType t) {
		return t.accept(this).qualify(t.qualifier);
	}
	
	ParamType visit(ParamAstType t) {
		return visit(t.getType()).getParamType(t.isRef, t.isFinal);
	}
	
	Type visit(BuiltinType t) {
		return Type.get(t, qualifier);
	}
	
	Type visit(Identifier i) {
		import d.semantic.identifier;
		return SymbolResolver!(delegate Type(identified) {
			static if(is(typeof(identified) : Type)) {
				return identified.qualify(qualifier);
			} else {
				return pass.raiseCondition!Type(i.location, i.toString(pass.context) ~ " isn't an type.");
			}
		})(pass).visit(i);
	}
	
	Type visitPointerOf(AstType t) {
		return visit(t).getPointer(qualifier);
	}
	
	Type visitSliceOf(AstType t) {
		return visit(t).getSlice(qualifier);
	}
	
	Type visitArrayOf(AstExpression size, AstType t) {
		auto type = visit(t);
		
		import d.semantic.expression;
		return buildArray(ExpressionVisitor(pass).visit(size), type);
	}
	
	import d.ir.expression;
	private Type buildArray(Expression size, Type t) {
		import d.semantic.caster, d.semantic.expression;
		auto s = evalIntegral(buildImplicitCast(
			pass,
			size.location,
			pass.object.getSizeT().type,
			size,
		));
		
		return t.getArray(s, qualifier);
	}
	
	Type visitMapOf(AstType key, AstType t) {
		visit(t);
		visit(key);
		assert(0, "Map are not implemented.");
	}
	
	Type visitBracketOf(Identifier ikey, AstType t) {
		auto type = visit(t);
		
		import d.semantic.identifier;
		return SymbolResolver!(delegate Type(identified) {
			alias T = typeof(identified);
			static if (is(T : Type)) {
				assert(0, "Not implemented.");
			} else static if (is(T: Expression)) {
				return buildArray(identified, type);
			} else {
				return pass.raiseCondition!Type(ikey.location, ikey.toString(pass.context) ~ " isn't an type.");
			}
		})(pass).visit(ikey);
	}
	
	Type visit(FunctionAstType t) {
		assert(t.contexts.length == 0, "Delegate are not supported.");
		
		auto oldQualifier = qualifier;
		scope(exit) qualifier = oldQualifier;
		
		qualifier = TypeQualifier.Mutable;
		
		auto returnType = visit(t.returnType);
		auto paramTypes = t.parameters.map!(t => visit(t)).array();
		
		return FunctionType(t.linkage, returnType, paramTypes, t.isVariadic).getType(oldQualifier);
	}
	/+
	Type visit(AstDelegateType t) {
		auto contextType = visit(t.context);
		
		auto oldQualifier = qualifier;
		scope(exit) qualifier = oldQualifier;
		
		qualifier = TypeQualifier.Mutable;
		
		auto returnType = visit(t.returnType);
		auto paramTypes = t.paramTypes.map!(t => visit(t)).array();
		
		return FunctionType(t.linkage, returnType, contextType, paramTypes, t.isVariadic).getType(oldQualifier);
	}
	+/
	import d.ast.expression;
	Type visit(AstExpression e) {
		import d.semantic.expression;
		return ExpressionVisitor(pass).visit(e).type.qualify(qualifier);
	}
	
	Type visitTypeOfReturn() {
		assert(0, "typeof(return) is not implemented.");
	}
}

