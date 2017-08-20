#!/usr/bin/perl

$RE_string =     qr{"((?:\\.|[^\\"])*)"};
$RE_string_one = qr{'((?:\\.|[^\\'])*)'}; #"

sub splitexpr {
    my ($e) = @_;
    if ($$e{'typ'}{'typ'} eq 'id' &&
	$$e{'typ'}{'val'} eq 'if') {
	return ($$e{'o'}[0],$$e{'o'}[1]);
    }
    return ($e,undef);
}

sub exprtoperlstr {
    my ($ctx,$e) = @_;
    my $r = "";
    return "<none>" if (!defined($e));
    if ($$e{'typ'}{'typ'} eq 'id' &&
	$$e{'typ'}{'val'} eq 'if') {
	return
	    exprtoperlstr($ctx,$$e{'o'}[0])." if ".
	    exprtoperlstr($ctx,$$e{'o'}[1]) ;
    }
    elsif ($$e{'typ'}{'typ'} eq 'id') {
	if ($$e{'typ'}{'val'} eq 'y')    { return "'y'"; }
	elsif ($$e{'typ'}{'val'} eq 'n') { return "'n'"; }
	elsif ($$e{'typ'}{'val'} eq 'm') { return "'m'"; }
	else {
	    my $id = $$e{'typ'}{'val'};
	    $$ctx{'used'}{$id} = 1; 
	    return '$$c{"'.$id.'"}';
	}
    }
    elsif ($$e{'typ'}{'typ'} eq 'str') {
	return "'".$$e{'typ'}{'val'}."'";
    }
    elsif ($$e{'typ'}{'typ'} eq '||' ||
	   $$e{'typ'}{'typ'} eq '&&' ||
	   $$e{'typ'}{'typ'} eq '!=' ||
	   $$e{'typ'}{'typ'} eq '==' ||
	   $$e{'typ'}{'typ'} eq '=') {
	my $perlop = $$e{'typ'}{'typ'};
	if ($$e{'typ'}{'typ'} eq '!=') {
	    $perlop = "ne";
	} elsif ($$e{'typ'}{'typ'} eq '==' ||
		 $$e{'typ'}{'typ'} eq '=') {
	    $perlop = "eq";
	}
	return "(".
	    exprtoperlstr($ctx,$$e{'o'}[0])." $perlop ".
	    exprtoperlstr($ctx,$$e{'o'}[1]).")";
    }
    elsif ($$e{'typ'}{'typ'} eq '!') {
	return '('.$$e{'typ'}{'typ'}.
	    exprtoperlstr($ctx,$ctx,$$e{'o'}[0]).")";
    } else {
	die ("Unknown ast ".Dumper($e));
    }
    return $r;
}

sub exprtostr {
    my ($e) = @_;
    my $r = "";
    return "<none>" if (!defined($e));
    if ($$e{'typ'}{'typ'} eq 'id' &&
	$$e{'typ'}{'val'} eq 'if') {
	return
	    exprtostr($$e{'o'}[0])." if ".
	    exprtostr($$e{'o'}[1]) ;
    }
    elsif ($$e{'typ'}{'typ'} eq 'id') {
	return $$e{'typ'}{'val'};
    }
    elsif ($$e{'typ'}{'typ'} eq 'str') {
	return "'".$$e{'typ'}{'val'}."'";
    }
    elsif ($$e{'typ'}{'typ'} eq '||' ||
	   $$e{'typ'}{'typ'} eq '&&' ||
	   $$e{'typ'}{'typ'} eq '!=' ||
	   $$e{'typ'}{'typ'} eq '==' ||
	   $$e{'typ'}{'typ'} eq '=') {
	return "(".
	    exprtostr($$e{'o'}[0]).$$e{'typ'}{'typ'}.
	    exprtostr($$e{'o'}[1]).")";
    }
    elsif ($$e{'typ'}{'typ'} eq '!') {
	return '('.$$e{'typ'}{'typ'}.
	    exprtostr($$e{'o'}[0]).")";
    } else {
	die ("Unknown ast ".Dumper($e));
    }
    return $r;
}

sub tokenize {
    my ($a) = @_;
    my @r = ();
    while (length($a)) {
	if($a =~ /^\s*($id)/) {
	    $a = $';
	    push(@r,{'typ'=>'id', 'val'=>$1});
	}
	elsif($a =~ /^\s*((?:!=))/) {
	    $a = $';
	    push(@r,{'typ'=> $1, 'val'=>undef});
	}
	elsif($a =~ /^\s*$RE_string/) {
	    $a = $';
	    push(@r,{'typ'=> 'str', 'val'=>$1});
	}
	elsif($a =~ /^\s*$RE_string_one/) {
	    $a = $';
	    push(@r,{'typ'=> 'str', 'val'=>$1});
	}
	elsif($a =~ /^\s*(=)/) {
	    $a = $';
	    push(@r,{'typ'=> $1, 'val'=>undef});
	}
	elsif($a =~ /^\s*((?:[!()]|&&|\|\|))/) {
	    $a = $';
	    push(@r,{'typ'=> $1, 'val'=>undef});
	}
	elsif($a =~ /^\s*#.*$/) {
	    $a = $';
	}
	elsif($a =~ /^\s*$/) {
	    $a = $';
	}
	else {
	    die("Cannot parse expr '$a'\n");
	}
    }
    return @r;
}

sub cur {
    my ($ctx,$tokctx) = @_;
    return ($$tokctx{'toks'}[$$tokctx{'tokidx'}]);
}

sub nexttok {
    my ($ctx,$tokctx) = @_;
    $$tokctx{'tokidx'}++;
    return cur($ctx,$tokctx);
}

sub parseprimary {
    my ($ctx,$tokctx) = @_;
    my $r = undef;
    ($tok) = cur($ctx,$tokctx);
    if ($$tok{typ} eq "str") {
	$r = { 'typ' => $tok};
    }
    elsif ($$tok{typ} eq "id") {
	$r = { 'typ' => $tok};
    }
    elsif ($$tok{typ} eq "(") {
	($tok) = nexttok($ctx,$tokctx);
	$r = parselor($ctx,$tokctx);
    }
    else
    {
	die("Expect id or val: cur:\n".Dumper($tok));
    }
    ($tok) = nexttok($ctx,$tokctx);
    return $r;
}

sub parseun {
    my ($ctx,$tokctx) = @_;
    ($tok) = cur($ctx,$tokctx);
    if ($$tok{typ} eq "!") {
	my $op = $tok;
	($tok) = nexttok($ctx,$tokctx);
	$r = { 'typ' => $op, 'o'=>[parseprimary($ctx,$tokctx)]};;
    } else {
	$r = parseprimary($ctx,$tokctx);
    }
    return $r;
}

sub parseeq {
    my ($ctx,$tokctx) = @_;
    my $r = parseun($ctx,$tokctx);
    ($tok) = cur($ctx,$tokctx);
    if ($$tok{'typ'} eq "==" ||
	$$tok{'typ'} eq "=" ||
	$$tok{'typ'} eq "!=") {
	my $op = $tok;
	($tok) = nexttok($ctx,$tokctx);
	$r = { 'typ' => $op, 'o'=>[$r, parseun($ctx,$tokctx)]};;
    }
    return $r;
}

sub parseland {
    my ($ctx,$tokctx) = @_;
    my $r = parseeq($ctx,$tokctx);
    ($tok) = cur($ctx,$tokctx);
    while ($$tok{'typ'} eq "&&") {
	my $op = $tok;
	($tok) = nexttok($ctx,$tokctx);
	$r = { 'typ' => $op, 'o'=>[$r, parseeq($ctx,$tokctx)]};;
    }
    return $r;
}

sub parselor {
    my ($ctx,$tokctx) = @_;
    my $r = parseland($ctx,$tokctx);
    ($tok) = cur($ctx,$tokctx);
    while ($$tok{'typ'} eq "||") {
	my $op = $tok;
	($tok) = nexttok($ctx,$tokctx);
	$r = { 'typ' => $op, 'o'=>[$r, parseland($ctx,$tokctx)]};;
    }
    return $r;
}

sub parseexpr {
    my ($ctx,$a) = @_;
    my @a = tokenize($a);
    # print(" Tokenize '$a':". Dumper(@a)."\n");
    my $tokctx = {'toks'=>\@a, 'tokidx'=>0};
    my $e = undef;
    if(scalar(@a)) {
	$e = parselor($ctx, $tokctx);
	if ($$tok{'typ'} eq "id" &&
	    $$tok{'val'} eq "if") {
	    my $op = $tok;
	    ($tok) = nexttok($ctx,$tokctx);
	    my $g = parselor($ctx, $tokctx);
	    $e = { 'typ' => $op, 'o'=>[$e, $g]};
	}
    };

    if($$tokctx{'tokidx'} < scalar(@a)) {
	die("Cannot parse '$a'". $$tokctx{'tokidx'});
    }
    #print(Dumper($e));
    return $e;
}

sub parseguart {
    my ($ctx, $guard) = @_;
    $guard =~ s/[#].*$//g;
    if ($guard =~ /^\s*if (.*)$/) {
	my $e = parseexpr($ctx, $1);
	print ("  # expr: ".exprtostr($e)."\n");
    } elsif ($guard =~ /^\s*$/) {
    } else {
	die("Cannot parse select options '$guard'");
    }
}

sub slurpone {
    my ($ctx,$a,$ctxone) = @_;
    $$ctxone{'depends'} = [];
    $$ctxone{'default'} = [];
    $$ctxone{'select'} = [];
    my @r = ();
    while (scalar(@$a)) {
	last if ($$a[0] =~ /^[a-zA-Z]/ &&
		 ! ($$a[0] =~ /^depends/  ||
		    $$a[0] =~ /^tristate/
		    
		 ));
	push(@r, shift(@$a));
    }
    my @_r = map { $_ =~ s/^\s*//; $_ } @r;
    while (scalar(@_r)) {
	my $r = shift(@_r);
	print ("  Parse option '$r'\n");
	next if ($r =~ /^\s*$/);

	if ($r =~ /^int\s+(.*)$/ ||
	    $r =~ /^int\s*$/) {
	    my ($n) = $1;
	    die ("type already defined : >$$ctxone{'typ'}< ") if (defined($$ctxone{'typ'}) && !($$ctxone{'typ'} eq 'int'));
	    $$ctxone{'typ'} = 'int';
	    $$ctxone{'id'} = $n if (length($n));
	    
	    my ($val) = ($1);
	    my $e = parseexpr($ctx, $val);
	    print ("  # expr-int: ".exprtostr($e)."\n");
	}
	elsif ($r =~ /^hex\s+(.*)$/ ||
	       $r =~ /^hex\s*$/) {
	    my ($n) = $1;
	    die ("type already defined : >$$ctxone{'typ'}< ") if (defined($$ctxone{'typ'}) && !($$ctxone{'typ'} eq 'hex'));
	    $$ctxone{'typ'} = 'hex';
	    $$ctxone{'id'} = $n if (length($n));
	    my ($val) = ($1);
	    my $e = parseexpr($ctx, $val);
	    print ("  # expr-hex: ".exprtostr($e)."\n");

	}
	elsif ($r =~ /^bool\s+(.*)$/ ||
	       $r =~ /^bool\s*$/) {# note: might follow by "if ...", i.e. bool "a" if flag
	    my ($n) = $1;
	    die ("type already defined : >$$ctxone{'typ'}< ") if (defined($$ctxone{'typ'}) && !($$ctxone{'typ'} eq 'bool'));
	    $$ctxone{'typ'} = 'bool';
	    my ($val) = ($1);
	    $$ctxone{'id'} = $n if (length($n));
	    my $e = parseexpr($ctx, $val);
	    print ("  # expr-bool: ".exprtostr($e)."\n");

	}
	elsif ($r =~ /^tristate\s+(.*)$/ ||
	       $r =~ /^tristate\s*$/) {
	    my ($n) = $1;
	    die ("type already defined : >$$ctxone{'typ'}< ") if (defined($$ctxone{'typ'}) && !($$ctxone{'typ'} eq 'tristate'));
	    $$ctxone{'typ'} = 'tristate';
	    $$ctxone{'id'} = $n if (length($n));
	    my ($val) = ($1);
	    my $e = parseexpr($ctx, $val);
	    print ("  # expr-tristate: ".exprtostr($e)."\n");

	}
	elsif ($r =~ /^string\s+(.*)/ || 
	       $r =~ /^string\s*$/) {
	    my ($n) = $1;
	    die ("type already defined : >$$ctxone{'typ'}< ") if (defined($$ctxone{'typ'}) && !($$ctxone{'typ'} eq 'string'));
	    $$ctxone{'typ'} = 'string';
	    $$ctxone{'id'} = $n if (length($n));
	    my ($val) = ($1);
	    my $e = parseexpr($ctx, $val);
	    print ("  # expr-string: ".exprtostr($e)."\n");
	}
	elsif ($r =~ /^prompt(.*)/) {
	    $$ctxone{'id'} = $1;
	}

	elsif ($r =~ /^default(.*)/) {
	    my ($id) = ($1);
	    my $e = parseexpr($ctx, $id);
	    push(@{$$ctxone{'default'}}, $e);
	}
	elsif ($r =~ /^depends\s+on\s+(.*)$/) {
	    my $e = parseexpr($ctx, $1);
	    print ("  # expr-depends: ".exprtostr($e)."\n");
	    push(@{$$ctxone{'depends'}}, $e);
	}
	elsif ($r =~ /^select(.*)$/) {
	    my ($g) = ($1);
	    my $e = parseexpr($ctx, $g);
	    print ("  # expr-select: ".exprtostr($e)."\n");
	    push(@{$$ctxone{'select'}}, $e);
	}

	elsif ($r =~ /^option\s+($id)=($id)(.*)$/ ||
	       $r =~ /^option\s+($id)=$RE_string(.*)$/) {
	    my ($id,$v,$guard) = ($1,$2,$3);
	    print("Found '$1'\n");
 	    my $e = parseguart($ctx, $guard);
	}
	elsif ($r =~ /^option\s+($id)$/ ) { # option defconfig_list, followed bydefault list
	    my ($id,$v,$guard) = ($1,$2,$3);
 	    my $e = parseguart($ctx, $guard);
	}



	elsif ($r =~ /^def_bool\s+(.*)$/) {
	    my ($id) = ($1);
	    my $e = parseexpr($ctx, $id);
	    print ("  # expr-def-bool: ".exprtostr($e)."\n");
	}
	elsif ($r =~ /^def_tristate\s+(.*)/) {
	    my ($id) = ($1);
	    my $e = parseexpr($ctx, $id);
	    print ("  # expr-def-tristate: ".exprtostr($e)."\n");
	}
	elsif ($r =~ /^visible/) {
	}
	elsif ($r =~ /^range\s+([\-0-9]+)\s+(.*)/) {
	    my ($left,$right) = ($1,$2);
	    my $e = parseexpr($ctx, $right);
	}
	elsif ($r =~ /^\s*#/) {
	}
	elsif ($r =~ /^comment/) {
	}
	elsif ($r =~ /^(?:---)?help/) {
	    last;
	} else {
	    die ("Cannot parse option '$r' in $fn");
	}
    }

    return \@r;
}


sub loadkconf {
    my ($ctx,$fn) = @_;
    my $a = readfile($fn);
    $a =~ s/[\\]\n//g;
    #$a =~ s/[#][^\n]+//g;
    my @a = split("\n",$a);
    while (scalar(@a)) {
	my $l = shift(@a);
	next if ($l =~ /^\s*$/);

	print (" Parse '$l'\n");
	
	if ($l =~ /^config\s+($id)\s*$/ ||
	    $l =~ /^config\s*$/) {
	    my ($n) = ($1);
	    my $c = {'id' => $n, 'options' => []};
	    my $o = slurpone($ctx,\@a, $c);
	    push(@{$$ctx{'config'}},$c);
	    
	} elsif ($l =~ /^\s*source\s+"(.+)"$/ || $l =~ /^source\s+(.+)$/) {
	    my ($inc) = ($1);
	    loadkconf($ctx, $$ctx{'rootdir'}."/".$inc);

	} elsif ($l =~ /^menu\s+"(.+)"$/) {
	    my ($n) = ($1);
	    my $c = {'id' => $n, 'options' => []};
	    my $o = slurpone($ctx,\@a,$c);
	    push(@{$$ctx{'menues'}},$c);;
	    
	} elsif ($l =~ /^endmenu/) {
	    die("Endmenue without menue in '$fn'\n") if (scalar(@{$$ctx{'menues'}}) == 0);
	    pop(@{$$ctx{'menues'}});;
	    
	} elsif ($l =~ /^menuconfig/) {
	    my $o = slurpone($ctx,\@a);

	} elsif ($l =~ /^choice/) {
	    my $c = {'id' => $n, 'options' => []};
	    my $o = slurpone($ctx,\@a,$c);
	    push(@{$$ctx{'choice'}},$c);;

	} elsif ($l =~ /^endchoice/) {
	    die("Endchoice without choice in '$fn'\n") if (scalar(@{$$ctx{'choice'}}) == 0);
	    pop(@{$$ctx{'choice'}});;
	    
	} elsif ($l =~ /^if/) {
	    my $e = parseguart($ctx, $l);
	    push(@{$$ctx{'if'}},$e);;
	    
	} elsif ($l =~ /^endif/) {
	    die("endif without if\n") if (scalar(@{$$ctx{'if'}}) == 0);
	    
	} elsif ($l =~ /^\s*#.*/) {
	} elsif ($l =~ /^\s*comment/) {
	    my $o = slurpone($ctx,\@a);
	} else {
	    die ("Cannot parse '$l' in $fn");
	}
    }
}

sub parsekconf {
    my ($b) = @_;
    my ($d) = (dirname($b));
    my %ctx = ('rootdir' => $d."/../..",
	       'menues' => [],
	       'if' => [],
	       'config' => [],
	       'choice' => [] );
    print ("Load '$b' from $d\n");
    loadkconf(\%ctx,$b);
    die("open menue\n") if (!(scalar(@{$$ctx{'menues'}}) == 0));
    die("open if\n") if (!(scalar(@{$$ctx{'if'}}) == 0));
}

1;
