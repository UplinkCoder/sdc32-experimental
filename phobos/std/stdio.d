/// Part of a 'mock' phobos used for testing. Not intended for real use.
module std.stdio;

void writeln(T)(T s) {
	printf("%.*s\n".ptr, s.length, s.ptr);
//	alias x = typeof(a);
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
