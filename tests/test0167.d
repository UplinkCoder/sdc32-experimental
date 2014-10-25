//T compiles:yes
//T has-passed:yes
//T retval:42

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
	int[5] arr2;
	{
	arr2[0] = 1;
	arr2[1] = 2;  
	arr2[2] = 3;
	arr2[3] = 4;
	arr2[4] = 5;
	}

	
	foreach (n;arr) {
		res+= n/12;		
	}

	foreach(i,n;arr) { 
		res+=i*2;
		res+=(n/12)*2;
	}
	int r2;
	foreach(e;arr) {
		foreach(e2;arr2) {
			(e2%2)?r2--:r2++;
		}
	}

	res+=r2;
	
	foreach(c;"SDC!") {
		res++;
	}
	
//	SimpleInputRange sir;
//	foreach(e;sir) {
//		writeln(e);
//	}

	return(cast(int)res);
}
