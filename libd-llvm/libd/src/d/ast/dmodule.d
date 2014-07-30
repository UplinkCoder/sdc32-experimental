module d.ast.dmodule;

import d.ast.base;
import d.ast.declaration;

/**
 * A D module
 */
class Module : Package {
	Declaration[] declarations;
	
	this(Location location, Name name, Name[] packages, Declaration[] declarations) {
		super(location, name, packages);
		
		this.declarations = declarations;
	}
}

