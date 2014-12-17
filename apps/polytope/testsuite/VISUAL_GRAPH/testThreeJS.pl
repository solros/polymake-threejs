enable_if_configured("common::threejs.rules") or return;
script("test_filters_threejs");

my $p1=cube(3);
my $p2=icosahedron();
my $p5=regular_24_cell();

my $colors = sub {
	my $i = shift;
	if ($i%3 == 0) {
		return 'blue';
	}
	if ($i%3 == 1) {
		return 'black';
	}
	if ($i%3 == 2) {
		return 'white';
	}
};

threejs($p1->VISUAL_GRAPH(VertexColor=>$colors, seed=>1), File=>diff_with("1three", filter_threejs()))

	and

threejs(compose($p2->VISUAL_GRAPH(EdgeColor=>'red',VertexColor=>'black', seed=>1), $p2->VISUAL_DUAL_GRAPH(EdgeColor=>'blue',VertexColor=>'white', seed=>1)), File=>diff_with("2three", filter_threejs()))

	and

threejs($p5->VISUAL_GRAPH(VertexLabels=>'hidden', VertexThickness=>3, seed=>1), File=>diff_with("3three", filter_threejs()));
