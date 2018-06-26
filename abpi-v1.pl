use strict;
use LWP::UserAgent;
use HTML::Entities;
use URI::URL;
use HTTP::Cookies;
use URI::Escape;
use HTTP::Request;
use bytes;
require "C:/DeHavilland/PERL_Web/DB_Dehaviland.pm";
# require "D:/Dehavilland/Scripts/Perl_Web/DB_Dehaviland.pm";


my $file='Cookie.txt';
my $ua=LWP::UserAgent->new;
$ua->agent("User-Agent: Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.2.3) Gecko/20100401 Firefox/3.6.3 (.NET CLR 3.5.30729)");


############Database Initialization########
my $dbh = &DB_Dehaviland::DbConnection();
###########################################

our $Loaded;
my $Coucil_ID='DEHPR13';

my $input_url = 'http://www.abpi.org.uk/media-centre/newsreleases/Pages/default.aspx';
my $List_content = &Get_Content($input_url);
my $Home_Url_Domain;	
if($input_url=~m/(https?\:\/\/[^\/]*?)\//is)
{
	$Home_Url_Domain=$1;
}
while($List_content =~ m/<div\s*class\=\"newsDescription\">\s*<a\s*href\=\"([^>]*?)\"/igs)
{
	my $title = &Trim($1);
	my $news_page_link = $1;
	if ( $news_page_link !~ m/^\s*https?\:/is && $news_page_link !~ m/^\s*$/ )
	{
		$news_page_link=$Home_Url_Domain.'/'.$news_page_link;
	}
	print "Link=>$news_page_link\n";
	my $Page_content = &Get_Content($news_page_link);
	my $news_information = &collect_information($Page_content,$news_page_link);
}


sub collect_information()
{
	my $content = shift;
	my $news_page_link = shift;
	my ($header,$event_date,$event_content,$summary,$typecode,$onhold);
	$typecode = '106010';
	$onhold = 'True';
	if($content =~ m/<h2\s*class\=\"post_title\">\s*([^>]*?)\s*<\/h2>/is)
	{
		$header = &Trim($1);
		$header = &WebContent_Trim($header);
		# $header = &DB_Dehaviland::WebContent_Trim($header);
	}
	if($content =~ m/Posted\s*in[\w\W]*?<\/a>[^>]*?<\/span>\s*([^>]*?)\s*</is)
	{
		$event_date = &Trim($1);
		if($event_date =~ m/(\d+)\W(\d+)\W(\d+)/is)
		{
			$event_date = $3.'-'.$2.'-'.$1.' 00:00:00.0';
		}
		
	}
	if($content =~ m/(<div\s*class\=\"post_main\">[\w\W]*?<div\s*class\=\"posting_footer\">)/is)
	{
		$event_content = &WebContent_Trim($1);
		# $event_content = &DB_Dehaviland::WebContent_Trim($1);
		# print "EventConten=>$event_content\n";
	}
	
	my $heading="ABPI - $header";
	my $detail=$event_content;
	$news_page_link=~s/\&/&amp;/igs;
	my $news_information = "
	<heading>$heading</heading>
	<content>$detail</content>
	<typecode>$typecode</typecode>
	<datetime>$event_date</datetime>
	<summary>$summary</summary>
	<onhold>$onhold</onhold>
	<url>$news_page_link</url>
	";
	$news_information=~s/[^[:print:]\n]+//igs;
	# &Webservice_Send($news_information);
	# exit;
	
	my $dup_Status=&DB_Dehaviland::RetrievelContent_2($dbh,$Coucil_ID,$heading,$detail,$typecode,$event_date,$summary,$news_page_link,$onhold,$news_information);
	# print "Duplicate Status=>$dup_Status\n";
	
	&DB_Dehaviland::RetrievelContent_1($dbh,$Coucil_ID,$heading,$detail,$typecode,$event_date,$summary,$news_page_link,$onhold,$news_information,$dup_Status);
}

sub Webservice_Send()
{
	my $news_information = shift;
	my $xml_content = '<SOAP-ENV:Envelope
	 SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"
	 xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/"
	 xmlns:xsi="http://www.w3.org/1999/XMLSchema-instance"
	 xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/"
	 xmlns:xsd="http://www.w3.org/1999/XMLSchema">
	 <SOAP-ENV:Body>
	 <AddNewItem xmlns="http://tempuri.org/">'.$news_information.'</AddNewItem>
	</SOAP-ENV:Body>
	</SOAP-ENV:Envelope>
	
	<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <AddNewItemResponse xmlns="http://tempuri.org/">
      <AddNewItemResult>boolean</AddNewItemResult>
    </AddNewItemResponse>
  </soap:Body>
</soap:Envelope>
';
	open sr, ">sample.xml";
	print sr $xml_content;
	# print  $content;
	close sr;
	my $userAgent = LWP::UserAgent->new();
	my $request = HTTP::Request->new(POST => 'http://webservices1.dehavilland.co.uk/KapowService5/newservice.asmx ');
	$request->header(SOAPAction => '"http://tempuri.org/AddNewItem"');
	$request->content($xml_content);
	$request->content_type("text/xml; charset=utf-8");
	my $response = $userAgent->request($request);

	
	if($response->code == 200) {
		print $response->as_string;
		$Loaded='Y';
	}
	else {
		print $response->error_as_HTML;
		$Loaded='N';
		open(err,">>Notsent.txt");
		print err "$xml_content\n";
		close err;
	}
}


sub Trim
{
	my $text = shift;
	$text =~ s/<[^>]*?>/ /igs;
	$text =~ s/\s+/ /igs;
	$text =~ s/^\s+|\s+$//igs;
	 decode_entities($text);
	return($text);
}

sub News_Content_Trim
{
	my $text = shift;
	$text =~ s/<\/p>/news_newline/igs;
	$text =~ s/<[^>]*?>/ /igs;
	$text =~ s/\&nbsp\;/ /igs;
	$text =~ s/\s+/ /igs;
	$text =~ s/^\s+|\s+$//igs;
	$text =~ s/news_newline/\n/igs;
	decode_entities($text);
	return($text);
}

sub Get_Content
{
	my $url = shift;
	my $rerun_count;
	print "url :; $url \n";
	Home:
	my $cookie = HTTP::Cookies->new(file=>$0."_cookie.txt",autosave=>1);
	$url =~ s/^\s+|\s+$//g;
	$url =~ s/amp\;//g;

	$ua->cookie_jar($cookie);
	my $req = HTTP::Request->new(GET=>"$url");
	$req->header("Accept"=>"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"); 
	$req->header("Accept-Language"=>"en-US,en;q=0.5"); 
	$req->header("Content-Type"=>"application/x-www-form-urlencoded"); 
	my $res = $ua->request($req); 

	$cookie->extract_cookies($res);
	$cookie->save;
	$cookie->add_cookie_header($req);
	my $code=$res->code;
	# print "\nCODE :: $code";
	my $content;
	if($code =~ m/20/is)
	{
		$content = $res->content;
	}
	else
	{
		if ( $rerun_count <= 3 )
		{
			$rerun_count++;
			goto Home;
		}
	}
	open sr, ">play1.html";
	print sr $content;
	# print  $content;
	close sr;
	return($content);

}
sub WebContent_Trim
{
	my $data = shift;
	$data=~s/\s\s+/ /igs;
	$data=~s/^\s+|\s+$//igs;
	$data=~s/\&nbsp\;/ /igs;
	$data=~s/\&amp\;/&/igs;
	encode_entities($data);
	$data =~s/\&nbsp\;/ /igs;
	$data =~s/\&amp\;pound\;/&#xA3;/igs;
	$data =~ s/\&pound\;/&#xA3;/igs;
	$data =~ s/\&brvbar\;/&amp;brvbar;/igs;
	$data =~ s/\&acirc\;\&\#128\;\&\#152\;/'/igs;
	$data =~ s/\&acirc\;\&\#128\;\&\#153\;/'/igs;
	$data =~ s/\&acirc\;\&\#128\;\&\#156\;/"/igs;
	$data =~ s/\&acirc\;\&\#128\;\&\#157\;/"/igs;
	$data =~ s/\&acirc\;\&\#128\;\&\#147\;/–/igs;
	$data =~ s/\&amp\;\#8217\;/'/igs;
	$data =~ s/\&amp\;\#8211\;/–/igs;
	$data =~ s/\&amp\;lsquo\;/'/igs;
	$data =~ s/\&amp\;rsquo\;/'/igs;
	$data =~ s/\&amp\;ndash\;/–/igs;
	$data =~ s/\&amp\;ldquo\;/"/igs;
	$data =~ s/\&amp\;rdquo\;/"/igs;
	$data =~ s/\&amp\;bull\;/•/igs;
	$data =~ s/\&amp\;reg\;/®/igs;
	$data =~ s/\&amp\;\#039;/'/igs;
	$data =~ s/\&amp\;\#39\;/'/igs;
	$data =~s/\&\#39;/'/igs;
	$data =~ s/\&frac/&amp;frac/igs;
	$data =~ s/\&Atilde\;/&amp;Atilde;/igs;
	$data =~ s/\&shy\;/&amp;shy;/igs;
	$data =~ s/\&middot\;/.../igs;
	$data =~ s/\&sup3\;/&amp;sup3;/igs;
	$data =~ s/\&acirc\;//igs;
	$data =~ s/\&yuml\;/ÿ/igs;
	$data =~ s/\&\#128\;\&cent\;/•/igs;
	$data =~ s/\&deg\;/°/igs;
	$data =~ s/\&reg\;/®/igs;
	$data =~ s/\&\#146\;/'/igs;
	$data =~ s/\&\#145\;/'/igs;
	$data =~ s/\&\#148\;\&uml\;//igs;
	$data =~ s/\&\#130\;\&not\;/€/igs;
	$data =~ s/\&amp\;Atilde\;\&uml\;/è/igs;
	$data =~ s/\&amp\;Atilde\;\&copy\;/é/igs;
	$data =~ s/\&\#148\;&cent\;/•/igs;
	$data =~ s/\&\#128\;\&\#148\;/—/igs;
	$data =~ s/\&amp\;Atilde\;\&iexcl\;\'&amp\;Atilde\;\&amp\;shy\;/á'i/igs;
	$data =~ s/\&copy\;/©/igs;
	$data =~ s/\&\#148\;\&amp\;brvbar\;/.../igs;
	$data =~ s/\&\#147\;/"/igs;
	$data =~ s/\&\#148\;\&\#157\;/"/igs;
	$data =~ s/\&not\;/¬/igs;
	$data =~ s/\&cedil\;/¸/igs;
	$data =~ s/\&ordm\;/º/igs;
	$data =~ s/\&amp\;Atilde\;\&acute\;/ô/igs;
	$data =~ s/\&sup1\;/¹/igs;
	$data =~ s/\&sup2\;/²/igs;
	
	return($data);
}
	
