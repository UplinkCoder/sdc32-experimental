void main() {
	import std.stdio;

	auto _body = CStatement(CStatementEnum.creturnstatement);

	_body.creturnstatement = CReturnStatement();
	_body.creturnstatement.expr = CExpression();
	_body.creturnstatement.expr.Etype = CExpressionEnum.cintegerliteralexpression;
	_body.creturnstatement.expr.cintergerliteralexpression = CIntegerLiteralExpression();
	_body.creturnstatement.expr.cintergerliteralexpression.Ttype = CTypeEnum.cint;
	_body.creturnstatement.expr.cintergerliteralexpression._ulong = 42;

	CFunction __main = CFunction(0, CType(CTypeEnum.culong), [], _body, "return42");
	writeln(print(__main));
}

struct CType {
	CTypeEnum Ttype;

	union {
		CArrayType* carray;
		CStructType* cstruct;
		CPointerType* cpointer;
		CFunctionType* cfunction;
	} 
	
}

//struct Symbol {
//	enum SymbolType {
//		Unresolved,
//		Variable,
//		Function,
//	}
//
//	string name;
//	CType type;
//	
//}

struct CPointerType {
	CType type;
}

struct CFunctionType {
	CType returnType;

	CType[] parameters;
}

struct CStructType {
	string name;
	struct CStructMember {
		string name;
		CType type;
	}

	CStructMember[] members;
}

struct CArrayType {
	uint length; // 0 means unkown e.g. Pointer
	CType type;
	
}

enum CTypeEnum {
	none,
	
	cchar,

	cshort,
	cint,
	clong,
	clonglong,

	cuchar,
	cushort,
	cuint,
	culong,
	culonglong,


	_cfloat,
	_cdouble,

	// UDA
	cstruct,

	//Composite
	cpointer,
	carray,
	cfunction,

}

struct CVariable {
	uint varid;

	CType type;
	string name;
	CExpression val;
}

struct CFunction {
	uint funid;
	CType returnType;
	CVariable[] params;
	CStatement _body;
	string name;

	@property CType funType() {
		CType funT;
		funT.Ttype = CTypeEnum.cfunction;
		funT.cfunction = new CFunctionType();
		funT.cfunction.returnType = returnType;
		foreach(param;params) {
			funT.cfunction.parameters ~= param.type;
		}

		return funT;
	}

}

enum CStatementEnum {
	creturnstatement,
	cblockstatement,
	cexpressionstatement,
}

struct CReturnStatement {
	CExpression expr;
}

struct CBlockStatement {
	CStatement[] statements;
}

struct CExpressionStatement {
	CExpression expr;
}

struct CStatement {
	CStatementEnum Stype;

	union {
		CReturnStatement creturnstatement;
		CBlockStatement cblockstatement;
		CExpressionStatement cexpressionstatement;
	}

}

enum CExpressionEnum {
	cintegerliteralexpression,
	cfloatliteralexpression,
	cstringliteralexpression,
	carrayexpression,
	ccallexpression,
	cvariableexpression,
	cstructliteralexpression,
	cbinaryexpression,
	cunaryexpression,

}

struct CExpression {
	CExpressionEnum Etype;
	union {
		CIntegerLiteralExpression cintergerliteralexpression;
		CVariableExpression cvariableexpression;
	}

}

struct CVariableExpression {
	CVariable cvariable;
}

struct CIntegerLiteralExpression {
	CTypeEnum Ttype;


	union {
		ulong _ulong;
		long _long;
	}

	invariant {
		assert(Ttype >= CTypeEnum.cshort && Ttype <= CTypeEnum.culonglong);
	}
}

struct CFloatLiteralExpression {
	CTypeEnum Etype;

	double _double;

	invariant {
		assert(Etype == CTypeEnum._cfloat || Etype == CTypeEnum._cdouble);
	}
}

struct CCallExpression {
	CFunction cfunction;
	CExpression[] params;
}

string print(CStatement cs) {
	switch (cs.Stype) with (CStatementEnum) {
		case cblockstatement : return print(cs.cblockstatement);
		case creturnstatement : return print(cs.creturnstatement);
		case cexpressionstatement : return print(cs.cexpressionstatement);
	}
}

string print(CExpression ce) {
	switch (ce.Etype) with (CExpressionEnum) {
		case cintegerliteralexpression : return (print(ce.cintergerliteralexpression));
	}
}

string print (CIntegerLiteralExpression ie) {
	import std.conv;
	switch (ie.Ttype) with (CTypeEnum) {
		case cushort, cuint : return to!string(ie._ulong);
		case culong : return to!string (ie._ulong) ~ "ul";
		case culonglong : return to!string (ie._ulong) ~ "ull";

		case cshort, cint : return to!string(ie._long);
		case clong : return to!string (ie._long) ~ "l";
		case clonglong : return to!string (ie._long) ~ "ll";
	}
}

string print(CExpressionStatement es) {
	return print(es.expr) ~ ";"; 
}

string print(CBlockStatement bs) {
	string stringRep = "{";
	foreach(stmt;bs.statements) {
		stringRep ~= print(stmt);
	}
	stringRep ~= "}";

	return stringRep;
}

string print(CReturnStatement rs) {
	return "return " ~ "(" ~ print(rs.expr) ~ ");";
}

string print(CType ct) {
	final switch(ct.Ttype) with (CTypeEnum) {
		case none : throw new Exception("None shall not be!");

		case cchar : return "char";
		case cuchar : return "unsigned char";
		case cshort : return "char short";
		case cushort : return "unsigned short";
		case cint : return "int";
		case cuint : return "unsigned int";
		case clong: return "long";
		case culong : return "unsigned long";
		case clonglong : return "longlong";
		case culonglong : return "unsigned longlong";
		case _cfloat : return "float";
		case _cdouble : return "double";
		
		case cpointer : return print(ct.cpointer.type)  ~ "*";
		case carray : return print(ct.carray.type)  ~ "[]";

		case cstruct : return "struct "  ~ ct.cstruct.name;
		case cfunction : throw new Exception("FunctionTypes currently not supported");
	}
}

string print(CFunction cf) {
	string stringRep = print(cf.returnType) ~" "~ cf.name ~ "(";

	foreach(param;cf.params) {
		stringRep ~= print(param) ~ ", ";
	}

	stringRep = cf.params.length ? stringRep[0 .. $-2] : stringRep;

	stringRep ~= ") ";	

	if (cf._body.Stype == CStatementEnum.cblockstatement) {
		stringRep ~= print(cf._body);
	} else {
		stringRep ~= "{" ~ print(cf._body) ~ "}";
	}
	return stringRep;
}

string print(CVariable cv, bool withType = false) {
	return (withType ? print(cv.type) : "") ~ cv.name;
}

unittest {
	auto _body = CStatement(CStatementEnum.creturnstatement);

	_body.creturnstatement = CReturnStatement();
	_body.creturnstatement.expr = CExpression();
	_body.creturnstatement.expr.Etype = CExpressionEnum.cintegerliteralexpression;
	_body.creturnstatement.expr.cintergerliteralexpression = CIntegerLiteralExpression();
	_body.creturnstatement.expr.cintergerliteralexpression.Ttype = CTypeEnum.cint;
	_body.creturnstatement.expr.cintergerliteralexpression._ulong = 1;

	CFunction __main = CFunction(0, CType(CTypeEnum.cint), [], _body, "main");
	assert(print(__main) == "int main() {return (1);}");

	CType __char_ptr_ptr;
	__char_ptr_ptr.Ttype = CTypeEnum.cpointer;
	__char_ptr_ptr.cpointer = new CPointerType(CType(CTypeEnum.cpointer));
	(*__char_ptr_ptr.cpointer).type.cpointer = new CPointerType(CType(CTypeEnum.cchar));

	assert(print(__char_ptr_ptr) == "char**");

}
