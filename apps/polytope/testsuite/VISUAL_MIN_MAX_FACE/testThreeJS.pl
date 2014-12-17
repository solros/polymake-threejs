enable_if_configured("common::threejs.rules") or return;
script("test_filters_threejs");

my $p1=new Polytope(VERTICES=>cube(3)->VERTICES, LP=>new LinearProgram(LINEAR_OBJECTIVE=>[0,1,0,0]));
my $p2=new Polytope(VERTICES=>icosahedron()->VERTICES, LP=>new LinearProgram(LINEAR_OBJECTIVE=>[0,1,0,0]));


threejs($p1->VISUAL->MIN_MAX_FACE(max=>'blue'), File=>diff_with("1three", filter_threejs()))

	and

threejs($p2->VISUAL->MIN_MAX_FACE(max=>'blue'), File=>diff_with("2three", filter_threejs()));
