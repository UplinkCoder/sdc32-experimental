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
		import d.ast.base;
		import d.semantic.declaration;
		auto dv = DeclarationVisitor(pass, AddContext.Yes, Visibility.Private);
		auto syms = dv.flatten(s.declaration);
		scheduler.require(syms);
		
		flattenedStmts ~= syms.map!(d => new SymbolStatement(d)).array();
	}
	
	void visit(AstExpressionStatement s) {
		import d.semantic.expression;
		auto ev = ExpressionVisitor(pass);
		
		flattenedStmts ~= new ExpressionStatement(ev.visit(s.expression));
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
		
		auto condition = buildExplicitCast(pass, s.condition.location, getBuiltin(TypeKind.Bool), ExpressionVisitor(pass).visit(s.condition));
		auto then = autoBlock(s.then);
		
		Statement elseStatement;
		if(s.elseStatement) {
			elseStatement = autoBlock(s.elseStatement);
		}
		
		flattenedStmts ~= new IfStatement(s.location, condition, then, elseStatement);
	}
	
	void visit(AstWhileStatement w) {
		import d.semantic.expression;
		auto ev = ExpressionVisitor(pass);
		
		auto condition = buildExplicitCast(pass, w.condition.location, getBuiltin(TypeKind.Bool), ev.visit(w.condition));
		auto statement = autoBlock(w.statement);
		
		flattenedStmts ~= new WhileStatement(w.location, condition, statement);
	}
	
	void visit(AstDoWhileStatement w) {
		import d.semantic.expression;
		auto ev = ExpressionVisitor(pass);
		
		auto condition = buildExplicitCast(pass, w.condition.location, getBuiltin(TypeKind.Bool), ev.visit(w.condition));
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
		auto ev = ExpressionVisitor(pass);
		
		Expression condition;
		if(f.condition) {
			condition = buildExplicitCast(pass, f.condition.location, getBuiltin(TypeKind.Bool), ev.visit(f.condition));
		} else {
			condition = new BooleanLiteral(f.location, true);
		}
		
		Expression increment;
		if(f.increment) {
			increment = ev.visit(f.increment);
		} else {
			increment = new BooleanLiteral(f.location, true);
		}
		
		auto statement = autoBlock(f.statement);
		
		flattenedStmts[$ - 1] = new ForStatement(f.location, initialize, condition, increment, statement);
	}

	void visit(ForeachStatement fr) {
		auto oldScope = currentScope;
		scope(exit) currentScope = oldScope;
		currentScope = (cast(NestedScope) oldScope).clone();

		auto getVariableExpressoionFromDeclaration(VariableDeclaration vd,QualType t) {
			import d.semantic.defaultinitializer;
			import d.semantic.declaration;

			vd.value = InitBuilder(pass).visit(vd.location, t);
			auto syms = DeclarationVisitor(pass).flatten(vd);
			assert(syms.length == 1 && syms[] !is null, "VariableDecl in foreach has more then one Symbol?!?!");
			auto v = cast(Variable) syms[0];
			v.type = t;
			return new VariableExpression(vd.location, v);
		}

		import d.semantic.expression;
		import d.semantic.defaultinitializer;
		import d.exception;
		auto ev = ExpressionVisitor(pass);

		auto expr = ev.visit(fr.iterrated);
		QualType exprType = peelAlias(expr.type);

		auto at = cast(ArrayType) exprType.type;  
		auto st = cast(SliceType) exprType.type;
		if (at||st) {
			QualType elementType;
			Expression size;
			VariableExpression idx;
			VariableExpression elem;

			if (at) {
				elementType = at.elementType;
				size = new IntegerLiteral!false(fr.location,at.size,TypeKind.Uint);
			} else {
				import d.semantic.identifier;

				elementType = st.sliced;
				assert(0,"foreach can't do sliceTypes yet");
			}

			size.type = pass.object.getSizeT().type;

			if (fr.tupleElements.length==2) {
				idx = getVariableExpressoionFromDeclaration(fr.tupleElements[0], pass.object.getSizeT().type);
				elem = getVariableExpressoionFromDeclaration(fr.tupleElements[1], elementType);
			} else {
				idx = new VariableExpression(fr.location, new Variable(fr.location, pass.object.getSizeT().type, BuiltinName!"", InitBuilder(pass).visit(fr.location, pass.object.getSizeT.type)));
				elem = getVariableExpressoionFromDeclaration(fr.tupleElements[0], elementType);
			}
			
			auto inc =  new UnaryExpression(fr.location, idx.type, UnaryOp.PostInc, idx);
			auto cmpr = new BinaryExpression(fr.location, getBuiltin(TypeKind.Bool), BinaryOp.Less, idx, size);
			auto assign = new BinaryExpression(fr.location, elementType, BinaryOp.Assign, elem, new IndexExpression(fr.location, elementType, expr, [idx]));
			
			Statement[] stmts = [new ExpressionStatement(assign)];
			stmts ~= autoBlock(fr.statement);
			Statement stmt = new BlockStatement(fr.statement.location, stmts);
			flattenedStmts ~= new ForStatement(fr.location, new ExpressionStatement(idx), cmpr, inc, stmt);
		
		} else {
			throw new CompileException(expr.location, typeid(expr.type.type).toString~" is not supported as foreach argument (for now)");
		}
	}

	void visit(AstReturnStatement r) {
		import d.semantic.expression;
		auto ev = ExpressionVisitor(pass);
		
		auto value = ev.visit(r.value);
		
		// TODO: precompute autotype instead of managing it here.
		auto doCast = true;
		if(auto bt = cast(BuiltinType) returnType.type) {
			if(bt.kind == TypeKind.None) {
				// TODO: auto ref return.
				returnType = ParamType(value.type, false);
				doCast = false;
			}
		}
		
		if(doCast) {
			value = buildImplicitCast(pass, r.location, QualType(returnType.type, returnType.qualifier), value);
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
		auto ev = ExpressionVisitor(pass);
		
		auto expression = ev.visit(s.expression);
		auto statement = autoBlock(s.statement);
		
		flattenedStmts ~= new SwitchStatement(s.location, expression, statement);
	}
	
	void visit(AstCaseStatement s) {
		import d.semantic.expression;
		auto ev = ExpressionVisitor(pass);
		
		auto cases = s.cases.map!(e => pass.evaluate(ev.visit(e))).array();
		
		flattenedStmts ~= new CaseStatement(s.location, cases);
	}
	
	void visit(AstLabeledStatement s) {
		auto labelIndex = flattenedStmts.length;
		
		visit(s.statement);
		
		auto statement = flattenedStmts[labelIndex];
		
		flattenedStmts[labelIndex] = new LabeledStatement(s.location, s.label, statement);
	}
	
	void visit(GotoStatement s) {
		flattenedStmts ~= s;
	}
	
	void visit(AstScopeStatement s) {
		flattenedStmts ~= new ScopeStatement(s.location, s.kind, autoBlock(s.statement));
	}
	
	void visit(AstThrowStatement s) {
		import d.semantic.expression;
		auto ev = ExpressionVisitor(pass);
		
		// TODO: Check that this is throwable
		flattenedStmts ~= new ThrowStatement(s.location, ev.visit(s.value));
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
		auto ev = ExpressionVisitor(pass);
		
		auto condition = evaluate(buildExplicitCast(pass, s.condition.location, getBuiltin(TypeKind.Bool), ev.visit(s.condition)));
		
		if((cast(BooleanLiteral) condition).value) {
			foreach(item; s.items) {
				visit(item);
			}
		} else {
			foreach(item; s.elseItems) {
				visit(item);
			}
		}
	}
	
	void visit(Mixin!AstStatement s) {
		import d.semantic.expression;
		auto ev = ExpressionVisitor(pass);
		
		auto value = evaluate(ev.visit(s.value));
		if(auto str = cast(StringLiteral) value) {
			import d.lexer;
			auto source = new MixinSource(s.location, str.value);
			auto trange = lex!((line, begin, length) => Location(source, line, begin, length))(str.value ~ '\0', context);
			
			trange.match(TokenType.Begin);
			
			while(trange.front.type != TokenType.End) {
				visit(trange.parseStatement());
			}
		} else {
			assert(0, "mixin parameter should evalutate as a string.");
		}
	}
}

