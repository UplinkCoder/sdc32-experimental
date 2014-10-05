/+
﻿module sdc.repl;
import d.lexer;
import d.source;
import d.semantic.semantic;
import d.context;

class repl
{


	StringSource current_input;
	Context current_context;

	auto lex() {
		return lexSource(current_input,current_context);
	}

	auto eval(string code) {

	}

	unittest {
		assert(eval("\"Hello World\"") == "Hello World");
		assert(eval("22*2") == 44);
	}


}
+/
