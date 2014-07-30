import std.stdio;
int main() {
  
  string s="test";
  ulong[] u;
  for(int i;i<s.length;i++) {
  writeln(s);
  }
  return s.length.sizeof-u.length.sizeof;
}
