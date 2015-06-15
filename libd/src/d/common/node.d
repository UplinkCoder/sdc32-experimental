module d.common.node;

public import d.context.location;

class Node {
	Location location;
	Node parent;
	
	this(Location location,Node parent = null) {
		this.location = location;
		this.parent = parent;
	}

	invariant() {
		// FIXME: reenable this when ct paradoxes know their location.
		// assert(location != Location.init, "node location must never be init");
	}
final:
	import d.context.context;
	auto getFullLocation(Context c) const {
		return location.getFullLocation(c);
	}
}
