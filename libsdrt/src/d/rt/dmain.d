module d.rt.dmain;

extern(C):
void* malloc(uint size);
uint strlen(char* string);

int _Dmain(string[] args);

int main(int argc, char** argv) {
	try {
		string[] args;
		char*[] cargs;
		cargs.ptr = argv;
		cargs.length = argc;
		args.ptr = cast(string*)malloc(argc * 12);
		args.length = argc;

		foreach (i;0..argc) {
			(*(args.ptr+(i*8))).ptr = cast(char*) argv+(i*4);
			(*(args.ptr+(i*8))).length = strlen(cast(char*) argv+(i*4));
		}

		return _Dmain(args);
	} catch(Throwable t) {
		return 1;
	}
}

