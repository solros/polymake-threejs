enable_if_configured("common::threejs.rules") or return;
script("test_filters_threejs");

my $p1=cube(3);
my $p2=icosahedron();
my $p3=simplex(3);
my $p4=cube(2);
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

threejs($p1->VISUAL, File=>diff_with("1three", filter_threejs()))

	and

threejs($p2->VISUAL(FacetColor=>'blue', VertexColor=>'yellow', EdgeColor=>'red', EdgeThickness=>5), File=>diff_with("2three", filter_threejs()))

	and

threejs($p3->VISUAL(FacetColor=>$colors, VertexColor=>$colors), File=>diff_with("3three", filter_threejs()))

	and
	
threejs($p4->VISUAL, File=>diff_with("4three", filter_threejs()))

	and

threejs($p5->VISUAL(EdgeColor=>'blue', VertexStyle=>'hidden'), File=>diff_with("5three", filter_threejs()))

	and

threejs($p1->VISUAL(FacetTransparency=>sub{(shift)/6}, VertexThickness=>sub{(shift)}, VertexLabels=>'hidden'), File=>diff_with("6three", filter_threejs()))

	and

threejs($p1->VISUAL(FacetStyle=>'hidden',EdgeStyle=>'hidden', VertexThickness=>sub{(shift)}), File=>diff_with("7three", filter_threejs()));

