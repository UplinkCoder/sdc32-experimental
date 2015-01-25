module d.semantic.statement;

import d.semantic.caster;
import d.semantic.semantic;

import d.ast.conditional;
import d.ast.declaration;
import d.ast.expression;
import d.ast.statement;
import d.ast.type;

import d.ir.dscope;
import d.ir.expression;
import d.ir.statement;
import d.ir.symbol;
import d.ir.type;

import d.parser.base;
import d.parser.statement;

import std.algorithm;
import std.array;

alias BlockStatement = d.ir.statement.BlockStatement;
alias ExpressionStatement = d.ir.statement.ExpressionStatement;
alias IfStatement = d.ir.statement.IfStatement;
alias WhileStatement = d.ir.statement.WhileStatement;
alias DoWhileStatement = d.ir.statement.DoWhileStatement;
alias ForStatement = d.ir.statement.ForStatement;
alias ReturnStatement = d.ir.statement.ReturnStatement;
alias SwitchStatement = d.ir.statement.SwitchStatement;
alias CaseStatement = d.ir.statement.CaseStatement;
alias LabeledStatement = d.ir.statement.LabeledStatement;
alias ScopeStatement = d.ir.statement.ScopeStatement;
alias ThrowStatement = d.ir.statement.ThrowStatement;
alias CatchBlock = d.ir.statement.CatchBlock;

struct StatementVisitor {
	private SemanticPass pass;
	alias pass this;
	
	private Statement[] flattenedStmts;
	
	this(SemanticPass pass) {
		this.pass = pass;
	}
	
	BlockStatement flatten(AstBlockStatement b) {
		auto oldFlattenedStmts = flattenedStmts;
		scope(exit) flattenedStmts = oldFlattenedStmts;
		
		flattenedStmts = [];
		
		foreach(ref s; b.statements) {
			visit(s);
		}
		
		return new BlockStatement(b.location, flattenedStmts);
	}
	
	void visit(AstStatement s) {
		return this.dispatch(s);
	}
	
	void visit(AstBlockStatement b) {
		auto oldScope = currentScope;
		scope(exit) currentScope = oldScope;
		
		currentScope = (cast(NestedScope) oldScope).clone();
		
		flattenedStmts ~= flatten(b);
	}
	
	void visit(DeclarationStatement s) {
		import d.semantic.declaration;
		auto syms = DeclarationVisitor(pass, AddContext.Yes, Visibility.Private).flatten(s.declaration);
		scheduler.require(syms);
		
		flattenedStmts ~= syms.map!(d => new SymbolStatement(d)).array();
	}
	
	void visit(AstExpressionStatement s) {
		import d.semantic.expression;
		flattenedStmts ~= new ExpressionStatement(ExpressionVisitor(pass).visit(s.expression));
	}
	
	private auto autoBlock(AstStatement s) {
		auto oldScope = currentScope;
		scope(exit) currentScope = oldScope;
		
		currentScope = (cast(NestedScope) oldScope).clone();
		
		if(auto b = cast(AstBlockStatement) s) {
			return flatten(b);
		}
		
		return flatten(new AstBlockStatement(s.location, [s]));
	}
	
	void visit(AstIfStatement s) {
		import d.semantic.expression;
		auto condition = buildExplicitCast(pass, s.condition.location, Type.get(BuiltinType.Bool), ExpressionVisitor(pass).visit(s.condition));
		auto then = autoBlock(s.then);
		
		Statement elseStatement;
		if(s.elseStatement) {
			elseStatement = autoBlock(s.elseStatement);
		}
		
		flattenedStmts ~= new IfStatement(s.location, condition, then, elseStatement);
	}
	
	void visit(AstWhileStatement w) {
		import d.semantic.expression;
		auto condition = buildExplicitCast(pass, w.condition.location, Type.get(BuiltinType.Bool), ExpressionVisitor(pass).visit(w.condition));
		auto statement = autoBlock(w.statement);
		
		flattenedStmts ~= new WhileStatement(w.location, condition, statement);
	}
	
	void visit(AstDoWhileStatement w) {
		import d.semantic.expression;
		auto condition = buildExplicitCast(pass, w.condition.location, Type.get(BuiltinType.Bool), ExpressionVisitor(pass).visit(w.condition));
		auto statement = autoBlock(w.statement);
		
		flattenedStmts ~= new DoWhileStatement(w.location, condition, statement);
	}
	
	void visit(AstForStatement f) {
		auto oldScope = currentScope;
		scope(exit) currentScope = oldScope;
		
		currentScope = (cast(NestedScope) oldScope).clone();
		
		// FIXME: if initialize is flattened into several statement, scope is wrong.
		visit(f.initialize);
		auto initialize = flattenedStmts[$ - 1];
		
		import d.semantic.expression;
		Expression condition = f.condition
			? buildExplicitCast(pass, f.condition.location, Type.get(BuiltinType.Bool), ExpressionVisitor(pass).visit(f.condition))
			: new BooleanLiteral(f.location, true);
		
		Expression increment = f.increment
			? ExpressionVisitor(pass).visit(f.increment)
			: new BooleanLiteral(f.location, true);
		
		flattenedStmts[$ - 1] = new ForStatement(f.location, initialize, condition, increment, autoBlock(f.statement));
	}
	
	void visit(ForeachStatement f) {
		auto oldScope = currentScope;
		scope(exit) currentScope = oldScope;
		
		currentScope = (cast(NestedScope) oldScope).clone();
		
		assert(!f.reverse, "foreach_reverse not supported at this point.");
		
		import d.semantic.expression;
		auto iterated = ExpressionVisitor(pass).visit(f.iterated);
		
		import d.semantic.identifier;
		auto length = SymbolResolver!(delegate Expression (e) {
			static if(is(typeof(e) : Expression)) {
				return e;
			} else {
				return pass.raiseCondition!Expression(iterated.location, typeid(e).toString() ~ " is not a valid length.");
			}
		})(pass).resolveInExpression(iterated.location, iterated, BuiltinName!"length");
		
		Variable idx;
		
		auto loc = f.location;
		switch(f.tupleElements.length) {
			case 1 :
				import d.semantic.defaultinitializer;
				idx = new Variable(loc, length.type, BuiltinName!"", InitBuilder(pass, loc).visit(length.type));
				
				idx.step = Step.Processed;
				break;
			
			case 2 :
				auto idxDecl = f.tupleElements[0];
				assert(!idxDecl.type.isRef, "index can't be ref");
				
				import d.semantic.type;
				auto t = idxDecl.type.getType().isAuto
					? length.type
					: TypeVisitor(pass).visit(idxDecl.type.getType());
				
				auto idxLoc = idxDecl.location;
				
				import d.semantic.defaultinitializer;
				idx = new Variable(idxLoc, t, idxDecl.name, InitBuilder(pass, idxLoc).visit(t));
				
				idx.step = Step.Processed;
				currentScope.addSymbol(idx);
				
				break;
			
			default :
				assert(0, "Wrong number of elements");
		}
		
		assert(idx);
		
		auto initialize = new SymbolStatement(idx);
		auto idxExpr = new VariableExpression(idx.location, idx);
		auto condition = new BinaryExpression(loc, Type.get(BuiltinType.Bool), BinaryOp.Less, idxExpr, length);
		auto increment = new UnaryExpression(loc, idxExpr.type, UnaryOp.PreInc, idxExpr);
		
		auto iType = iterated.type.getCanonical();
		assert(iType.hasElement, "Only array and slice are supported for now.");
		
		Type et = iType.element;
		
		auto eDecl = f.tupleElements[$ - 1];
		auto eLoc = eDecl.location;
		
		import d.semantic.expression;
		auto eVal = ExpressionVisitor(pass).getIndex(eLoc, iterated, idxExpr);
		auto eType = eVal.type.getParamType(eDecl.type.isRef, false);
		
		if (!eDecl.type.getType().isAuto) {
			import d.semantic.type;
			eType = TypeVisitor(pass).visit(eDecl.type);
			eVal = buildImplicitCast(pass, eLoc, eType.getType(), eVal);
		}
		
		auto element = new Variable(eLoc, eType, eDecl.name, eVal);
		element.step = Step.Processed;
		currentScope.addSymbol(element);
		
		auto assign = new BinaryExpression(loc, eType.getType(), BinaryOp.Assign, new VariableExpression(eLoc, element), eVal);
		auto stmt = new BlockStatement(f.statement.location, [new ExpressionStatement(assign), autoBlock(f.statement)]);
		
		flattenedStmts ~= new ForStatement(loc, initialize, condition, increment, stmt);
	}
	
	void visit(ForeachRangeStatement f) {
		auto oldScope = currentScope;
		scope(exit) currentScope = oldScope;
		
		currentScope = (cast(NestedScope) oldScope).clone();
		
		assert(!f.reverse, "foreach_reverse not supported at this point.");
		
		import d.semantic.expression;
		auto start = ExpressionVisitor(pass).visit(f.start);
		auto stop  = ExpressionVisitor(pass).visit(f.stop);
		
		assert(f.tupleElements.length == 1, "Wrong number of elements");
		auto iDecl = f.tupleElements[0];
		
		auto loc = f.location;
		
		import d.semantic.type, d.semantic.typepromotion;
		auto type = iDecl.type.getType().isAuto
			? getPromotedType(pass, loc, start.type, stop.type)
			: TypeVisitor(pass).visit(iDecl.type).getType();
		
		start = buildImplicitCast(pass, start.location, type, start);
		stop  = buildImplicitCast(pass, stop.location, type, stop);
		auto idx = new Variable(iDecl.location, type.getParamType(iDecl.type.isRef, false), iDecl.name, start);
		
		idx.step = Step.Processed;
		currentScope.addSymbol(idx);
		
		auto initialize = new SymbolStatement(idx);
		auto idxExpr = new VariableExpression(idx.location, idx);
		auto condition = new BinaryExpression(loc, Type.get(BuiltinType.Bool), BinaryOp.Less, idxExpr, stop);
		auto increment = new UnaryExpression(loc, type, UnaryOp.PreInc, idxExpr);
		
		flattenedStmts ~= new ForStatement(loc, initialize, condition, increment, autoBlock(f.statement));
	}
	
	void visit(AstReturnStatement r) {
		import d.semantic.expression;
		auto value = ExpressionVisitor(pass).visit(r.value);
		
		// TODO: precompute autotype instead of managing it here.
		auto doCast = true;
		auto rt = returnType.getType();
		
		// TODO: Handle auto return by specifying it to this visitor instead of deducing it in dubious ways.
		if (rt.kind == TypeKind.Builtin && rt.qualifier == TypeQualifier.Mutable && rt.builtin == BuiltinType.None) {
			// TODO: auto ref return.
			returnType = value.type.getParamType(false, false);
			doCast = false;
		}
		
		if (doCast) {
			value = buildImplicitCast(pass, r.location, returnType.getType(), value);
		}
		
		flattenedStmts ~= new ReturnStatement(r.location, value);
	}
	
	void visit(BreakStatement s) {
		flattenedStmts ~= s;
	}
	
	void visit(ContinueStatement s) {
		flattenedStmts ~= s;
	}
	
	void visit(AstSwitchStatement s) {
		import d.semantic.expression;
		auto expression = ExpressionVisitor(pass).visit(s.expression);
		
		flattenedStmts ~= new SwitchStatement(s.location, expression, autoBlock(s.statement));
	}
	
	void visit(AstCaseStatement s) {
		import d.semantic.expression;
		auto cases = s.cases.map!(e => pass.evaluate(ExpressionVisitor(pass).visit(e))).array();
		
		flattenedStmts ~= new CaseStatement(s.location, cases);
	}
	
	void visit(AstLabeledStatement s) {
		auto labelIndex = flattenedStmts.length;
		
		visit(s.statement);
		
		flattenedStmts[labelIndex] = new LabeledStatement(s.location, s.label, flattenedStmts[labelIndex]);
	}
	
	void visit(GotoStatement s) {
		flattenedStmts ~= s;
	}
	
	void visit(AstScopeStatement s) {
		flattenedStmts ~= new ScopeStatement(s.location, s.kind, autoBlock(s.statement));
	}
	
	void visit(AstThrowStatement s) {
		// TODO: Check that this is throwable
		import d.semantic.expression;
		flattenedStmts ~= new ThrowStatement(s.location, ExpressionVisitor(pass).visit(s.value));
	}
	
	void visit(AstTryStatement s) {
		auto tryStmt = autoBlock(s.statement);
		
		import d.semantic.identifier : AliasResolver;
		auto iv = AliasResolver!(function Class(identified) {
			static if(is(typeof(identified) : Symbol)) {
				if(auto c = cast(Class) identified) {
					return c;
				}
			}
			
			static if(is(typeof(identified.location))) {
				import d.exception;
				throw new CompileException(identified.location, typeid(identified).toString() ~ " is not a class.");
			} else {
				// for typeof(null)
				assert(0);
			}
		})(pass);
		
		CatchBlock[] catches = s.catches.map!(c => CatchBlock(c.location, iv.visit(c.type), c.name, autoBlock(c.statement))).array();
		
		if(s.finallyBlock) {
			flattenedStmts ~= new ScopeStatement(s.finallyBlock.location, ScopeKind.Exit, autoBlock(s.finallyBlock));
		}
		
		flattenedStmts ~= new TryStatement(s.location, tryStmt, catches);
	}
	
	void visit(StaticIf!AstStatement s) {
		import d.semantic.expression;
		auto condition = evalIntegral(buildExplicitCast(
			pass,
			s.condition.location,
			Type.get(BuiltinType.Bool),
			ExpressionVisitor(pass).visit(s.condition),
		));
		
		auto items = condition
			? s.items
			: s.elseItems;
		
		foreach(item; items) {
			visit(item);
		}
	}
	
	void visit(Mixin!AstStatement s) {
		import d.semantic.expression;
		auto str = evalString(ExpressionVisitor(pass).visit(s.value));
		
		import d.lexer;
		auto source = new MixinSource(s.location, str);
		auto trange = lex!((line, begin, length) => Location(source, line, begin, length))(str ~ '\0', context);
		
		trange.match(TokenType.Begin);
		while(trange.front.type != TokenType.End) {
			visit(trange.parseStatement());
		}
	}
}

