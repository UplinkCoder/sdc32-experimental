/// Part of a 'mock' phobos used for testing. Not intended for real use.
module std.stdio;

void writeln(T)(T s) {
	static if (is(T:string)) {
		printf("%.*s\n".ptr, s.length, s.ptr);
	} else static if (is(T:bool)) {
		string str = (s ? "true" : "false");
		printf("%.*s\n".ptr, str.length, str.ptr);
		//TODO make this work! it has to do with instanciating
		// The same template inside a template (maybe just ITFI)
	//	writeln(str);
	} else static if (is(T:int)) {
		printf("%d", s);
	}

	return ;
}
/+
void writeln(T:string)(T s) {
	printf("%.*s\n".ptr, s.length, s.ptr);
}

void writeln(T:int)(T i) {
	printf("%d\n".ptr, i);
}
+/
