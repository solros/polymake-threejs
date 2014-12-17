enable_if_configured("common::threejs.rules") or return;
script("test_filters_threejs");

	
threejs(cube(3)->VISUAL->LATTICE(PointColor=>'black', PointThickness=>3), File=>diff_with("1three", filter_threejs()))

	and

threejs(cube(3,3/2,-1)->VISUAL->LATTICE_COLORED, File=>diff_with("2three", filter_threejs()));

