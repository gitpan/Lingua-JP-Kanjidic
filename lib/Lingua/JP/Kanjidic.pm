package Lingua::JP::Kanjidic;
use 5.006;
use strict;
use warnings;
use Encode;
use Encode::JP;
use Tie::File;
our $VERSION = '1.0';

my %joyo;

=head1 NAME

Lingua::JP::Kanjidic - Parse Jim Breen's kanji dictionary

=head1 SYNOPSIS

  use Lingua::JP::Kanjidic;
  system("wget http://ftp.monash.edu.au/pub/nihongo/kanjidic.gz");
  # Please see the license at
  # http://www.csse.monash.edu.au/groups/edrdg/licence.html
  system("gunzip kanjidic.gz");

  my $x = Lingua::JP::Kanjidic->new();

=head1 DESCRIPTION

This module parses the kanjidic file for information about individual
Japanese kanji characters. It can be used as a random-access reader or
as an iterator. 

=head2 METHODS

=head3 new

Creates a new kanjidic reader; you must pass in the path to a kanjidic
file, or it assumes the "kanjidic" file in the current directory.

=cut

sub new {
    my ($self, $file) = @_;
    $file ||= "kanjidic";
    my @stuff;
    tie @stuff, 'Tie::File', $file or die "Couldn't tie $file: $@";
    bless {
        pos => 1,
        cache => {},
        last_sought => 0,
        file => \@stuff
    }, $self;
}

=head3 reset

Resets the iterator to the beginning of file.

=cut

sub reset { $_[0]->{pos} = 1 };

=head3 next

Returns the next line in the file as a C<Lingua::JP::Kanjidic::Kanji>
object (see below).

=cut

sub next {
    my $self = shift;
    $self->return_line($self->{pos}++);
}

=head2 return_line($i)

Returns line C<$i> in the file; does not affect the iterator. The line
is returned as a C<Lingua::JP::Kanjidic::Kanji> object.

=cut

sub return_line {
    my ($self, $i) = @_;
    my $line = decode("euc-jp",$self->{file}->[$i]);
    return unless $line;
    my $obj = Lingua::JP::Kanjidic::Kanji->new($line);
    $self->{cache}{$obj->{kanji}} = $obj if $obj;
}

=head2 lookup($kanji)

Looks up a particular kanji, returning the C<::Kanji> object. May be slow.
The kanji should be specified as a Unicode character.

=cut

sub lookup {
    my ($self, $kanji) = @_;
    return $self->{cache}{$kanji} if exists $self->{cache}{$kanji};
    for ($self->{last_sought}..$#{$self->{file}}) {
        my $obj = $self->return_line($_);
        $self->{last_sought} = $_;
        return $obj if $obj->kanji eq $kanji;
    }
    return;
}

=head2 KANJI OBJECT METHODS

The following methods are available on C<::Kanji> objects.

=head3 kanji

The Unicode character itself.

=head3 jis

The JIS encoding, as a hex string.

=head3 unicode

The Unicode codepoint for the character, as a hex string.

=head3 nelson

The index in Nelson Modern Reader's Japanese-English Character
Dictionary.

=head3 radical_nelson

The radical number, as given in Nelson.

=head3 radical

The classical radical number.

=head3 grade

The school grade in which this kanji is learnt.

=head3 strokes

The number of strokes in the kanji

=head3 halpern

The index in Halpern New Japanese-English Character Dictionary.

=head3 frequency

The frequency index of this kanji's occurrence.

=head3 new_nelson

The index number in The New Nelson Japanese-English Character Dictionary.

=head3 henshall

The index number used in "A Guide To Remembering Japanese Characters" by
Kenneth G. Henshall.

=head3 gakken

The index number in the Gakken Kanji Dictionary ("A New Dictionary of
Kanji Usage").

=head3 heiseg

The index number used in "Remembering The Kanji" by James Heisig.

=head3 oneill

The index number in "Japanese Names", by P.G. O'Neill.

=head3 morohashi

The index number in the 13-volume Morohashi Daikanwajiten.

=head3 tuttle

The index number in The Kanji Dictionary (Tuttle 1996).

=cut

package Lingua::JP::Kanjidic::Kanji;
no strict;
sub AUTOLOAD { my $self = shift; $AUTOLOAD =~ s/(.*::)//; $self->{$AUTOLOAD}}
my $hex = qw/[a-f0-9A-F]/;
my %numbers = (
    N => "nelson",
    B => "radical_nelson",
    G => "grade",
    S => "strokes",
    H => "halpern",
    F => "frequency",
    V => "new_nelson",
    E => "henshall",
    K => "gakken",
    L => "heiseg",
    O => "oneill",
    MN => "morohashi",
    IN => "tuttle",
);

sub new {
    my ($class, $line) = @_;
    my $self = {};
    return if $line =~ /^# KANJIDIC/;
    $line =~ s/^(\w+)\s*// or die "Couldn't parse line $line" ; $self->{kanji} = $1;
    $line =~ s/^($hex+)\s*// or die "Couldn't parse JIS code from line $line" ; $self->{jis} = $1;
    $line =~ s/U($hex+)\s*// or die "Couldn't parse Unicode value from line $line" ; $self->{unicode} = $1;
    for (keys %numbers) {
        $line =~ s/\b($_)(\d+)\s*// and $self->{$numbers{$1}} = $2;
    }

=head3 skip

Jack Halpern's SKIP code. Note that separate copyrights apply to
commercial utilization of this code.

=cut

    $line =~ s/\bP([\d\-]+)\s*// and $self->{skip} = $1;

    $line =~ s/\bC(\d+)\s*// and $self->{radical} = $1;
    $self->{radical} ||= $self->{radical_nelson};

=head3 morohashi_page

The volume and page number in the Morohashi Daikanwajiten.

=cut

    $line =~ s/\bMP(\d+\.\d+)\s*// and $self->{morohashi_page} = $1;
    while ($line =~ s/\bD(\w)(\d+)\s*//) { $self->{additional}{$1} = $2 }

    $line =~ s/\bI(\d[a-z]\d+\.\d+)\s*// and $self->{spahn} = $1;

=head3 four_corner

Wang Chen's four corner code.

=cut

    $line =~ s/\bQ(\d{4}\.\d)\s*// and $self->{four_corner} = $1;
    $line =~ s/^\s*X\S+\s*//g;

=head3 korean / pinyin

An array reference of the Korean and Chinese readings of the kanji

=cut

    push @{$self->{$1 eq "W" ? "korean" : "pinyin"}}, $2 
        while $line =~ s/\s*([WY])(\w+\d?)\s*//;

=head3 meaning

An array reference of the English meanings of the kanji.

=cut

    push @{$self->{meaning}}, $1 while $line =~ s/{([^}]+)}\s*//;

=head3 hiragana

Kun-yomi readings for the character, returned as an array reference of
Unicode strings.

=head3 katakana

On-yomi readings for the character, returned as an array reference of
Unicode strings.

=head3 joyo

A binary flag indicating whether or not the kanji is joyo.

=cut

    push @{$self->{hiragana}}, $1 while $line =~ s/([\x{3041}-\x{309f}\.]+)\s*//;
    push @{$self->{katakana}}, $1 while $line =~ s/([\x{30a1}-\x{30ff}]+)\s*//;
    $line =~ s/T1\s*//;
    $self->{joyo} = exists $joyo{$self->{kanji}};

    bless $self, $class;
}


=head1 SEE ALSO

http://www.csse.monash.edu.au/~jwb/kanjidic_doc.html

=head1 AUTHOR

Simon Cozens, E<lt>simon@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004 by Simon Cozens

=cut

# Table of joyo kanji

package Lingua::JP::Kanjidic;
%joyo = map { chr(hex($_))=>1 } qw( 
4E00 4E5D 4E03 4E8C 4EBA 5165 516B 529B 5341 4E0B 4E09 5343 4E0A 53E3 571F 5915
5927 5973 5B50 5C0F 5C71 5DDD 4E94 5929 4E2D 516D 5186 624B 6587 65E5 6708 6728
6C34 706B 72AC 738B 6B63 51FA 672C 53F3 56DB 5DE6 7389 751F 7530 767D 76EE 77F3
7ACB 767E 5E74 4F11 5148 540D 5B57 65E9 6C17 7AF9 7CF8 8033 866B 6751 7537 753A
82B1 898B 8C9D 8D64 8DB3 8ECA 5B66 6797 7A7A 91D1 96E8 9752 8349 97F3 6821 68EE
5200 4E07 4E38 624D 5DE5 5F13 5185 5348 5C11 5143 4ECA 516C 5206 5207 53CB 592A
5F15 5FC3 6238 65B9 6B62 6BDB 7236 725B 534A 5E02 5317 53E4 53F0 5144 51AC 5916
5E83 6BCD 7528 77E2 4EA4 4F1A 5408 540C 56DE 5BFA 5730 591A 5149 5F53 6BCE 6C60
7C73 7FBD 8003 8089 81EA 8272 884C 897F 6765 4F55 4F5C 4F53 5F1F 56F3 58F0 58F2
5F62 6C7D 793E 89D2 8A00 8C37 8D70 8FD1 91CC 9EA6 753B 6771 4EAC 591C 76F4 56FD
59C9 59B9 5CA9 5E97 660E 6B69 77E5 9577 9580 663C 524D 5357 70B9 5BA4 5F8C 6625
661F 6D77 6D3B 601D 79D1 79CB 8336 8A08 98A8 98DF 9996 590F 5F31 539F 5BB6 5E30
6642 7D19 66F8 8A18 901A 99AC 9AD8 5F37 6559 7406 7D30 7D44 8239 9031 91CE 96EA
9B5A 9CE5 9EC4 9ED2 5834 6674 7B54 7D75 8CB7 671D 9053 756A 9593 96F2 5712 6570
65B0 697D 8A71 9060 96FB 9CF4 6B4C 7B97 8A9E 8AAD 805E 7DDA 89AA 982D 66DC 9854
4E01 4E88 5316 533A 53CD 592E 5E73 7533 4E16 7531 6C37 4E3B 4ED5 4ED6 4EE3 5199
53F7 53BB 6253 76AE 76BF 793C 4E21 66F2 5411 5DDE 5168 6B21 5B89 5B88 5F0F 6B7B
5217 7F8A 6709 8840 4F4F 52A9 533B 541B 5742 5C40 5F79 6295 5BFE 6C7A 7A76 8C46
8EAB 8FD4 8868 4E8B 80B2 4F7F 547D 5473 5E78 59CB 5B9F 5B9A 5CB8 6240 653E 6614
677F 6CF3 6CE8 6CE2 6CB9 53D7 7269 5177 59D4 548C 8005 53D6 670D 82E6 91CD 4E57
4FC2 54C1 5BA2 770C 5C4B 70AD 5EA6 5F85 6025 6307 6301 62FE 662D 76F8 67F1 6D0B
7551 754C 767A 7814 795E 79D2 7D1A 7F8E 8CA0 9001 8FFD 9762 5CF6 52C9 500D 771F
54E1 5BAE 5EAB 5EAD 65C5 6839 9152 6D88 6D41 75C5 606F 8377 8D77 901F 914D 9662
60AA 5546 52D5 5BBF 5E33 65CF 6DF1 7403 796D 7B2C 7B1B 7D42 7FD2 8EE2 9032 90FD
90E8 554F 7AE0 5BD2 6691 690D 6E29 6E56 6E2F 6E6F 767B 77ED 7AE5 7B49 7B46 7740
671F 52DD 8449 843D 8EFD 904B 904A 958B 968E 967D 96C6 60B2 98F2 6B6F 696D 611F
60F3 6697 6F22 798F 8A69 8DEF 8FB2 9244 610F 69D8 7DD1 7DF4 9280 99C5 9F3B 6A2A
7BB1 8AC7 8ABF 6A4B 6574 85AC 9928 984C 58EB 4E0D 592B 6B20 6C0F 6C11 53F2 5FC5
5931 5305 672B 672A 4EE5 4ED8 4EE4 52A0 53F8 529F 672D 8FBA 5370 4E89 4EF2 4F1D
5171 5146 5404 597D 6210 706F 8001 8863 6C42 675F 5175 4F4D 4F4E 5150 51B7 5225
52AA 52B4 544A 56F2 5B8C 6539 5E0C 6298 6750 5229 81E3 826F 82B8 521D 679C 5237
5352 5FF5 4F8B 5178 5468 5354 53C2 56FA 5B98 5E95 5E9C 5F84 677E 6BD2 6CE3 6CBB
6CD5 7267 7684 5B63 82F1 82BD 5358 7701 5909 4FE1 4FBF 8ECD 52C7 578B 5EFA 6628
6804 6D45 80C3 795D 7D00 7D04 8981 98DB 5019 501F 5009 5B6B 6848 5BB3 5E2F 5E2D
5F92 6319 6885 6B8B 6BBA 6D74 7279 7B11 7C89 6599 5DEE 8108 822A 8A13 9023 90E1
5DE3 5065 5074 505C 526F 5531 5802 5EB7 5F97 6551 68B0 6E05 671B 7523 83DC 7968
8CA8 6557 9678 535A 559C 9806 8857 6563 666F 6700 91CF 6E80 713C 7136 7121 7D66
7D50 899A 8C61 8CAF 8CBB 9054 968A 98EF 50CD 5869 6226 6975 7167 611B 7BC0 7D9A
7F6E 8178 8F9E 8A66 6B74 5BDF 65D7 6F01 7A2E 7BA1 8AAC 95A2 9759 5104 5668 8CDE
6A19 71B1 990A 8AB2 8F2A 9078 6A5F 7A4D 9332 89B3 985E 9A13 9858 93E1 7AF6 8B70
4E45 4ECF 652F 6BD4 53EF 65E7 6C38 53E5 5727 5F01 5E03 520A 72AF 793A 518D 4EEE
4EF6 4EFB 56E0 56E3 5728 820C 4F3C 4F59 5224 5747 5FD7 6761 707D 5FDC 5E8F 5FEB
6280 72B6 9632 6B66 627F 4FA1 820E 5238 5236 52B9 59BB 5C45 5F80 6027 62DB 6613
679D 6CB3 7248 80A5 8FF0 975E 4FDD 539A 6545 653F 67FB 72EC 7956 5247 9006 9000
8FF7 9650 5E2B 500B 4FEE 4FF5 76CA 80FD 5BB9 6069 683C 685C 7559 7834 7D20 8015
8CA1 9020 7387 8CA7 57FA 5A66 5BC4 5E38 5F35 8853 60C5 63A1 6388 63A5 65AD 6DB2
6DF7 73FE 7565 773C 52D9 79FB 7D4C 898F 8A31 8A2D 8CAC 967A 5099 55B6 5831 5BCC
5C5E 5FA9 63D0 691C 6E1B 6E2C 7A0E 7A0B 7D76 7D71 8A3C 8A55 8CC0 8CB8 8CBF 904E
52E2 5E79 6E96 640D 7981 7F6A 7FA9 7FA4 5893 5922 89E3 8C4A 8CC7 9271 9810 98FC
50CF 5883 5897 5FB3 6163 614B 69CB 6F14 7CBE 7DCF 7DBF 88FD 8907 9069 9178 92AD
9285 969B 96D1 9818 5C0E 6575 66B4 6F54 78BA 7DE8 8CDB 8CEA 8208 885B 71C3 7BC9
8F38 7E3E 8B1B 8B1D 7E54 8077 984D 8B58 8B77 4EA1 5BF8 5DF1 5E72 4EC1 5C3A 7247
518A 53CE 51E6 5E7C 5E81 7A74 5371 540E 7070 5438 5B58 5B87 5B85 673A 81F3 5426
6211 7CFB 5375 5FD8 5B5D 56F0 6279 79C1 4E71 5782 4E73 4F9B 4E26 523B 547C 5B97
5B99 5B9D 5C4A 5EF6 5FE0 62E1 62C5 62DD 679A 6CBF 82E5 770B 57CE 594F 59FF 5BA3
5C02 5DFB 5F8B 6620 67D3 6BB5 6D17 6D3E 7687 6CC9 7802 7D05 80CC 80BA 9769 8695
5024 4FF3 515A 5C55 5EA7 5F93 682A 5C06 73ED 79D8 7D14 7D0D 80F8 6717 8A0E 5C04
91DD 964D 9664 965B 9AA8 57DF 5BC6 6368 63A8 63A2 6E08 7570 76DB 8996 7A93 7FCC
8133 8457 8A2A 8A33 6B32 90F7 90F5 9589 9802 5C31 5584 5C0A 5272 5275 52E4 88C1
63EE 656C 6669 68D2 75DB 7B4B 7B56 8846 88C5 88DC 8A5E 8CB4 88CF 50B7 6696 6E90
8056 76DF 7D79 7F72 8179 84B8 5E55 8AA0 8CC3 7591 5C64 6A21 7A40 78C1 66AE 8AA4
8A8C 8A8D 95A3 969C 5287 6A29 6F6E 719F 8535 8AF8 8A95 8AD6 907A 596E 61B2 64CD
6A39 6FC0 7CD6 7E26 92FC 53B3 512A 7E2E 89A7 7C21 81E8 96E3 81D3 8B66 4E59 4E86
53C8 4E0E 53CA 4E08 5203 51E1 52FA 4E92 5F14 4E95 5347 4E39 4E4F 5301 5C6F 4ECB
5197 51F6 5208 5339 5384 53CC 5B54 5E7B 6597 65A4 4E14 4E19 7532 51F8 4E18 65A5
4ED9 51F9 53EC 5DE8 5360 56DA 5974 5C3C 5DE7 6255 6C41 7384 7518 77DB 8FBC 5F10
6731 540F 52A3 5145 5984 4F01 4EF0 4F10 4F0F 5211 65EC 65E8 5320 53EB 5410 5409
5982 5983 5C3D 5E06 5FD9 6271 673D 6734 6C5A 6C57 6C5F 58EE 7F36 808C 821F 828B
829D 5DE1 8FC5 4E9C 66F4 5BFF 52B1 542B 4F50 4F3A 4F38 4F46 4F2F 4F34 5449 514B
5374 541F 5439 5448 58F1 5751 574A 598A 59A8 5999 8096 5C3F 5C3E 5C90 653B 5FCC
5E8A 5EF7 5FCD 6212 623B 6297 6284 629E 628A 629C 6276 6291 6749 6C96 6CA2 6C88
6CA1 59A5 72C2 79C0 809D 5373 82B3 8F9B 8FCE 90A6 5CB3 5949 4EAB 76F2 4F9D 4F73
4F8D 4FAE 4F75 514D 523A 52BE 5353 53D4 576A 5947 5954 59D3 5B9C 5C1A 5C48 5CAC
5F26 5F81 5F7C 602A 6016 80A9 623F 62BC 62D0 62D2 62E0 62D8 62D9 62D3 62BD 62B5
62CD 62AB 62B1 62B9 6606 6607 67A2 6790 676F 67A0 6B27 80AF 6BB4 6CC1 6CBC 6CE5
6CCA 6CCC 6CB8 6CE1 708E 708A 7089 90AA 7948 7949 7A81 80A2 80AA 5230 830E 82D7
8302 8FED 8FEB 90B8 963B 9644 6589 751A 5E25 8877 5E7D 70BA 76FE 5351 54C0 4EAD
5E1D 4FAF 4FCA 4FB5 4FC3 4FD7 76C6 51A0 524A 52C5 8C9E 5378 5398 6020 53D9 54B2
57A3 5951 59FB 5B64 5C01 5CE1 5CE0 5F27 6094 6052 6068 6012 5A01 62EC 631F 62F7
6311 65BD 662F 5192 67B6 67AF 67C4 67F3 7686 6D2A 6D44 6D25 6D1E 7272 72ED 72E9
73CD 67D0 75AB 67D4 7815 7A83 7CFE 8010 80CE 80C6 80DE 81ED 8352 8358 8650 8A02
8D74 8ECC 9003 90CA 90CE 9999 525B 8870 755D 604B 5039 5012 5023 4FF8 502B 7FC1
517C 51C6 51CD 5263 5256 8105 533F 683D 7D22 6851 5506 54F2 57CB 5A2F 5A20 59EB
5A18 5BB4 5BB0 5BB5 5CF0 8CA2 5510 5F90 60A6 6050 606D 6075 609F 60A9 6247 632F
635C 633F 6355 654F 6838 685F 6813 6843 6B8A 6B89 6D66 6D78 6CF0 6D5C 6D6E 6D99
6D6A 70C8 755C 73E0 7554 75BE 75C7 75B2 7720 7832 7965 79F0 79DF 79E9 7C8B 7D1B
7D21 7D0B 8017 6065 8102 6715 80F4 81F4 822C 65E2 83EF 868A 88AB 8A17 8ED2 8FB1
5507 901D 9010 9013 9014 900F 914C 9665 9663 96BB 98E2 9B3C 5264 7ADC 7C9B 5C09
5F6B 507D 5076 5075 504F 5270 52D8 4E7E 559D 5553 552F 57F7 57F9 5800 5A5A 5A46
5BC2 5D0E 5D07 5D29 5EB6 5EB8 5F69 60A3 60E8 60DC 60BC 60A0 639B 6398 63B2 63A7
636E 63AA 6383 6392 63CF 659C 65CB 66F9 6BBB 8CAB 6DAF 6E07 6E13 6E0B 6DD1 6E09
6DE1 6DFB 6DBC 732B 731B 731F 74F6 7D2F 76D7 773A 7A92 7B26 7C97 7C98 7C92 7D3A
7D39 7D33 811A 8131 8C5A 8236 83D3 83CA 83CC 865A 86CD 86C7 888B 8A1F 8CA9 8D66
8EDF 9038 902E 90ED 9154 91C8 91E3 9670 9673 9676 966A 9686 9675 9EBB 658E 55AA
5965 86EE 5049 5098 508D 666E 559A 55AB 570F 582A 5805 5815 585A 5824 5854 5840
5A92 5A7F 638C 9805 5E45 5E3D 5E7E 5EC3 5ECA 5F3E 5C0B 5FA1 5FAA 614C 60F0 6109
60D1 96C7 6249 63E1 63F4 63DB 642D 63DA 63FA 6562 6681 6676 66FF 68FA 68CB 68DA
68DF 6B3E 6B3A 6B96 6E26 6ECB 6E7F 6E21 6E7E 716E 7336 7434 7573 5841 758E 75D8
75E2 786C 785D 786B 7B52 7CA7 7D5E 7D2B 7D61 8139 8155 846C 52DF 88D5 88C2 8A60
8A50 8A54 8A3A 8A34 8D8A 8D85 8DDD 8EF8 9047 9042 9045 904D 9162 920D 9591 9685
968F 7126 96C4 96F0 6BBF 68C4 50BE 5091 50B5 50AC 50E7 6148 52E7 8F09 55E3 5606
584A 5851 5857 5968 5AC1 5ACC 5BDB 5BDD 5EC9 5FAE 6168 611A 6101 614E 643A 643E
6442 642C 6687 697C 6B73 6ED1 6E9D 6EDE 6EDD 6F20 6EC5 6EB6 7159 7169 96C5 733F
732E 75F4 7761 7763 7881 798D 7985 7A1A 7D99 8170 8247 84C4 865E 865C 8910 88F8
89E6 8A72 8A70 8A87 8A73 8A89 8CCA 8CC4 8DE1 8DF5 8DF3 8F03 9055 9063 916C 916A
925B 9262 9234 9694 96F7 96F6 9774 9811 9812 98FE 98FD 9F13 8C6A 50D5 50DA 66A6
587E 596A 5AE1 5BE1 5BE7 8150 5F70 5FB4 618E 6162 6458 6982 96CC 6F06 6F38 6F2C
6EF4 6F02 6F2B 6F0F 7344 7891 7A32 7AEF 7B87 7DAD 7DB1 7DD2 7DB2 7F70 819C 6155
8A93 8A98 8E0A 906E 906D 9175 9177 9283 9291 9298 95A5 96A0 9700 99C6 99C4 9AEA
9B42 932C 7DEF 97FB 5F71 92ED 8B01 95B2 7E01 61B6 7A4F 7A3C 9913 58CA 61D0 5687
7372 7A6B 6F5F 8F44 61BE 6B53 74B0 76E3 7DE9 8266 9084 9451 8F1D 9A0E 5100 622F
64EC 72A0 7AAE 77EF 97FF 9A5A 51DD 7DCA 895F 8B39 7E70 52F2 85AB 6176 61A9 9D8F
9BE8 6483 61F8 8B19 8CE2 9855 9867 7A3F 8861 8CFC 58BE 61C7 9396 932F 64AE 64E6
66AB 8AEE 8CDC 74BD 7235 8DA3 5112 8972 919C 7363 77AC 6F64 9075 511F 7901 885D
9418 58CC 5B22 8B72 91B8 9320 5631 5BE9 85AA 9707 9318 9AC4 6F84 702C 8ACB 7C4D
6F5C 7E4A 85A6 9077 9BAE 7E55 790E 69FD 71E5 85FB 971C 9A12 8D08 6FEF 6FC1 8AFE
935B 58C7 92F3 99D0 61F2 8074 93AE 589C 7DE0 5FB9 64A4 8B04 8E0F 9A30 95D8 7BE4
66C7 7E04 6FC3 8987 8F29 8CE0 8584 7206 7E1B 7E41 85E9 7BC4 76E4 7F77 907F 8CD3
983B 6577 819A 8B5C 8CE6 821E 8986 5674 58B3 61A4 5E63 5F0A 58C1 7656 8217 7A42
7C3F 7E2B 8912 81A8 8B00 58A8 64B2 7FFB 6469 78E8 9B54 7E6D 9B45 9727 9ED9 8E8D
7652 8AED 6182 878D 6170 7AAF 8B21 7FFC 7F85 983C 6B04 6FEB 5C65 96E2 616E 5BEE
7642 7CE7 96A3 96B7 970A 9E97 9F62 64C1 9732 
)
