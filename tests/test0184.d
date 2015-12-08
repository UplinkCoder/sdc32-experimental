//T compiles:yes
//T has-passed:yes
//T retval:12
// Tests the Basic isExpression 



	struct S (int kind) {
		static if (kind == 1) {
			alias t = void;
		} else {
			alias b = uint;
		}	
	}
int main() {	
	class CwOP {
		bool _opEquals(CwOP rhs) {
			return this !is rhs;
		}
	}

	struct SwoOP {int a;}
 
	int a;
	assert(is(typeof(CwOP._opEquals)));
	
	assert(is(SwoOP));	
	assert(!is(typeof(SwoOP.opEquals)));
	S!1 s1;
	S!0 s0;

	assert(is(s1.t)); 

	assert(!is(s0.t));

	return a;
}
