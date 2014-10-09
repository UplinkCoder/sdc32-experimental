//T compiles:yes
//T has-passed:yes
//T retval:42

import std.stdio;
int main() {

	ubyte[4] arr;
/*	struct SimpleInputRange {
		int cnt;
		int front() {
			return cnt;
		}
		void popFront() {
			cnt++;
		}
		bool empty() {
			return cnt>10;
		}
	}
*/
	size_t res=0;

	arr[0] = cast(ubyte)12;
	arr[1] = cast(ubyte)24;
	arr[2] = cast(ubyte)36;
	arr[3] = cast(ubyte)48;

	foreach (n;arr) {
		res+= n/12;		
	}

	foreach(i,n;arr) { 
		res+=i*2;
		res+=(n/12)*2;
	}

	uint ran = 22;

	bool _true = true;
	bool _false = false; 
//	ran = ran?22:0;
//	SimpleInputRange sir;
//	foreach(e;sir) {
//		writeln(e);
//	}



	return(cast(int)res);
}
