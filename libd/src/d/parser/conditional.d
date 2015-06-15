module d.parser.conditional;

import d.ast.conditional;
import d.ast.declaration;
import d.ast.statement;

import d.parser.base;
import d.parser.declaration;
import d.parser.expression;
import d.parser.statement;

/**
 * Parse Version Declaration
 */
auto parseVersion(ItemType, TokenRange)(ref TokenRange trange) if(isTokenRange!TokenRange && (is(ItemType == AstStatement) || is(ItemType == Declaration))) {
	return trange.parseconditionalBlock!(true, ItemType)();
}

/**
 * Parse Debug Declaration
 */
auto parseDebug(ItemType, TokenRange)(ref TokenRange trange) if(isTokenRange!TokenRange && (is(ItemType == AstStatement) || is(ItemType == Declaration))) {
	return trange.parseconditionalBlock!(false, ItemType)();
}

private ItemType parseconditionalBlock(bool isVersion, ItemType, TokenRange)(ref TokenRange trange) {
	static if(isVersion) {
		alias TokenType.Version conditionalTokenType;
		alias Version!ItemType ConditionalType;
		alias VersionDefinition!ItemType DefinitionType;
	} else {
		alias TokenType.Debug conditionalTokenType;
		alias Debug!ItemType ConditionalType;
		alias DebugDefinition!ItemType DefinitionType;
	}
	
	Location location = trange.front.location;
	trange.match(conditionalTokenType);
	
	// TODO: refactor.
	switch(trange.front.type) with(TokenType) {
		case OpenParen :
			trange.popFront();
			
			import d.context.name;
			Name versionId;
			switch(trange.front.type) {
				case Identifier :
					versionId = trange.front.name;
					trange.match(Identifier);
					
					break;
				
				case Unittest :
					static if(isVersion) {
						trange.popFront();
						versionId = BuiltinName!"unittest";
						break;
					} else {
						// unittest isn't a special token for debug.
						goto default;
					}
					
				default :
					assert(0);
			}
			
			trange.match(TokenType.CloseParen);
			
			ItemType[] items = trange.parseItems!ItemType();
			ItemType[] elseItems;
			
			if(trange.front.type == Else) {
				trange.popFront();
				
				elseItems = trange.parseItems!ItemType();
			}
			
			return new ConditionalType(location, versionId, items, elseItems);
		
		case Equal :
			trange.popFront();
			auto versionId = trange.front.name;
			trange.match(Identifier);
			trange.match(Semicolon);
			
			return new DefinitionType(location, versionId);
		
		default :
			// TODO: error.
			assert(0);
	}
}

/**
 * Parse static if.
 */
ItemType parseStaticIf(ItemType, TokenRange)(ref TokenRange trange) if(isTokenRange!TokenRange && (is(ItemType == AstStatement) || is(ItemType == Declaration))) {
	auto location = trange.front.location;
	
	trange.match(TokenType.Static);
	trange.match(TokenType.If);
	trange.match(TokenType.OpenParen);
	
	auto condition = trange.parseExpression();
	
	trange.match(TokenType.CloseParen);
	
	ItemType[] items = trange.parseItems!ItemType();
	
	if(trange.front.type == TokenType.Else) {
		trange.popFront();
		
		ItemType[] elseItems = trange.parseItems!ItemType();
		
		return new StaticIf!ItemType(location, condition, items, elseItems);
	} else {
		return new StaticIf!ItemType(location, condition, items, []);
	}
}

/**
 * Parse the content of the conditionnal depending on if it is statement or declaration that are expected.
 */
private auto parseItems(ItemType, TokenRange)(ref TokenRange trange) {
	switch(trange.front.type) with(TokenType) {
		static if(is(ItemType == AstStatement)) {
			case OpenBrace :
				trange.popFront();
				
				ItemType[] items;
				while(trange.front.type != TokenType.CloseBrace) {
					items ~= trange.parseStatement();
				}
				
				trange.popFront();
				return items;
			
			default :
				return [trange.parseStatement()];
		} else {
			case OpenBrace :
				return trange.parseAggregate();
			
			case Colon :
				trange.popFront();
				return trange.parseAggregate!false();
			
			default :
				return [trange.parseDeclaration()];
		}
	}
}

/**
 * Parse mixins.
 */
auto parseMixin(ItemType, TokenRange)(ref TokenRange trange) if(isTokenRange!TokenRange && is(Mixin!ItemType)) {
	auto location = trange.front.location;
	
	trange.match(TokenType.Mixin);
	trange.match(TokenType.OpenParen);
	
	auto expression = trange.parseExpression();
	
	trange.match(TokenType.CloseParen);
	location.spanTo(trange.front.location);
	
	trange.match(TokenType.Semicolon);
	return new Mixin!ItemType(location, expression);
}

