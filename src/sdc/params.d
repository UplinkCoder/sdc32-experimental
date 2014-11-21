module sdc.params;

struct params
{
	string[] includePath;
	string[] libPath;
	string[] versions;
	uint optLevel;
	bool testMode;
	bool dontLink;
	uint bitWidth;
	bool outputSrc;
	bool outputBc; 
	string outputFile;
	bool verbose;
}

