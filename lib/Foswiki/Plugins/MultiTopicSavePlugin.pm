# See bottom of file for default license and copyright information

=begin TML

---+ package MultiTopicSavePlugin

This plugin enables saving content incl form data to multiple topics using
only a single submit.

It is typically used where you list content of a number of topics in a formatted
search which present the content as an HTML form with fields for each topic.

A submit button makes a rest call that causes this plugin to save the changed
date to all the topics listed.

=cut

# change the package name!!!
package Foswiki::Plugins::MultiTopicSavePlugin;

# Always use strict to enforce variable scoping
use strict;

use Foswiki::Func ();       # The plugins API
use Foswiki::Plugins ();    # For the API version

# $VERSION  should always be in the format$Rev: 5771 $ so that Foswiki can
# determine the checked-in status of the extension.
our $VERSION = '$Rev: 5771 $';

# $RELEASE is used in the "Find More Extensions" automation in configure.
our $RELEASE = '1.0';

# Short description of this plugin
# One line description, is shown in the %SYSTEMWEB%.TextFormattingRules topic:
our $SHORTDESCRIPTION =
  'Save form data to multiple topics in one single submission';

# No preferences set in the plugin topic. 
our $NO_PREFS_IN_TOPIC = 1;

=begin TML

---++ initPlugin($topic, $web, $user) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin topic is in
     (usually the same as =$Foswiki::cfg{SystemWebName}=)

Called to initialise the plugin. If everything is OK, should return
a non-zero value. On non-fatal failure, should write a message
using =Foswiki::Func::writeWarning= and return 0. In this case
%<nop>FAILEDPLUGINS% will indicate which plugins failed.

In the case of a catastrophic failure that will prevent the whole
installation from working safely, this handler may use 'die', which
will be trapped and reported in the browser.

__Note:__ Please align macro names with the Plugin name, e.g. if
your Plugin is called !FooBarPlugin, name macros FOOBAR and/or
FOOBARSOMETHING. This avoids namespace issues.

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    # Example code of how to get a preference value, register a macro
    # handler and register a RESTHandler (remove code you do not need)

    # Set your per-installation plugin configuration in LocalSite.cfg,
    # like this:
    # $Foswiki::cfg{Plugins}{EmptyPlugin}{ExampleSetting} = 1;
    # See %SYSTEMWEB%.DevelopingPlugins#ConfigSpec for information
    # on integrating your plugin configuration with =configure=.

    # Always provide a default in case the setting is not defined in
    # LocalSite.cfg. See %SYSTEMWEB%.Plugins for help in adding your plugin
    # configuration to the =configure= interface.
    # my $setting = $Foswiki::cfg{Plugins}{EmptyPlugin}{ExampleSetting} || 0;

    # Register the _EXAMPLETAG function to handle %EXAMPLETAG{...}%
    # This will be called whenever %EXAMPLETAG% or %EXAMPLETAG{...}% is
    # seen in the topic text.
    Foswiki::Func::registerTagHandler( 'MULTITOPICSAVESUBMIT',
                                       \&_MULTITOPICSAVESUBMIT
                                     );
                                     
    Foswiki::Func::registerTagHandler( 'MULTITOPICSAVEINPUT',
                                       \&_MULTITOPICSAVEINPUT
                                     );

    # Allow a sub to be called from the REST interface
    # using the provided alias
    Foswiki::Func::registerRESTHandler( 'multitopicsave',
                                        \&restMultiTopicSave,
                                        authenticate => 1,
                                        http_allow => 'POST',
                                        validate => 1
                                      );

    # Plugin correctly initialized
    return 1;
}

# The function used to handle the %MULTITOPICSAVESUBMIT{...}% macro
sub _MULTITOPICSAVESUBMIT {
    my($session, $params, $theTopic, $theWeb) = @_;
    # $session  - a reference to the Foswiki session object (if you don't know
    #             what this is, just ignore it)
    # $params=  - a reference to a Foswiki::Attrs object containing
    #             parameters.
    #             This can be used as a simple hash that maps parameter names
    #             to values, with _DEFAULT being the name for the default
    #             (unnamed) parameter.
    # $theTopic - name of the topic in the query
    # $theWeb   - name of the web in the query
    # Return: the result of processing the macro. This will replace the
    # macro call in the final text.

    # For example, %EXAMPLETAG{'hamburger' sideorder="onions"}%
    # $params->{_DEFAULT} will be 'hamburger'
    # $params->{sideorder} will be 'onions'
    
    my $result = "<input type='hidden' name='redirectweb' value='%WEB%' />" .
                 "<input type='hidden' name='redirecttopic' value='%TOPIC%' />" .
                 "<input type='submit' value='";
    $result .= $params->{_DEFAULT};
    $result .= "' />";
    
    return $result;
    
}

# The function used to handle the %MULTITOPICSAVEINPUT{...}% macro
sub _MULTITOPICSAVEINPUT {
    my($session, $params, $theTopic, $theWeb) = @_;
    # $session  - a reference to the Foswiki session object (if you don't know
    #             what this is, just ignore it)
    # $params=  - a reference to a Foswiki::Attrs object containing
    #             parameters.
    #             This can be used as a simple hash that maps parameter names
    #             to values, with _DEFAULT being the name for the default
    #             (unnamed) parameter.
    # $theTopic - name of the topic in the query
    # $theWeb   - name of the web in the query
    # Return: the result of processing the macro. This will replace the
    # macro call in the final text.

    # For example, %EXAMPLETAG{'hamburger' sideorder="onions"}%
    # $params->{_DEFAULT} will be 'hamburger'
    # INPUT will be 'onions'
    
    my $result = '';
    my $type = lc ( $params->{type} ) || 'text';
    my $size = $params->{size};                     # No default here
    my $targetweb = $params->{web} || $theWeb;
    my $targettopic = $params->{topic} || $theTopic;
    $targettopic = "$targetweb.$targettopic";
    my $multiple = $params->{multiple} || 0;
    my $field = $params->{_DEFAULT};
    my $value = defined $params->{value} ? $params->{value} : '';
    my @values = split( / *, */, $value );

    my @options = defined $params->{options} ? split(/ *, */, $params->{options} ) : ();

    if ( $type eq 'text' ) {
        $result = "<input class='foswikiInputField' type='text' ";
        $result .= "size='$size' " if defined $size;
        $result .= "name='multitopicsavefield{$targettopic}{$field}' ";
        $result .= "value='" . $value . "' />";
    }
    elsif ( $type eq 'textarea' ) {
        $result = "<textarea class='foswikiTextarea' ";
        if ( $size =~ m/(\d+)[xX](\d+)/ ) {
            my ($cols, $rows) = ( $1, $2 );
            $result .= "cols='$cols' rows='$rows' ";
        }
        $result .= "name='multitopicsavefield{$targettopic}{$field}'>";
        $result .= "$value";
        $result .= "</textarea>"
    }
    elsif ( $type eq 'radio' || $type eq 'checkbox' ) {
        my $initcounter = defined $size ? $size : 1;
        my $counter = $initcounter;
        $result = "<table style='border:none;border-style:none;border-width:0;padding-top:0;'>";
        foreach my $option ( @options ) {
            $result .= "<tr>" if ( $counter == $initcounter );
            $result .= "<td style='border:none;border-style:none;border-width:0;padding-top:0;'><input type='$type' ";
            $result .= "name='multitopicsavefield{$targettopic}{$field}' ";
            $result .= "value='" . $option . "' ";
            if ( $type eq 'radio' && $option eq $value ) {
                $result .= "checked='checked' ";
            }
            if ( $type eq 'checkbox' && grep (/$option/, @values ) ) {
                $result .= "checked='checked' ";
            }
            $result .= "/> $option </td>";
            unless ( --$counter ) {
                $result .= "</tr> ";
                $counter = $initcounter;
            }
        }
        $result .= "</tr>" if ( $counter != $initcounter );
        $result .= "</table>";
    }
    elsif ( $type eq 'select' ) {
        $result = "<select "
                  . "name='multitopicsavefield{$targettopic}{$field}' "
                  . "class='foswikiSelect' ";
                  
        $result .= "multiple='multiple' "
            if Foswiki::Func::isTrue( $multiple );
        
        $result .= "size='$size'"
            if defined $size;
        
        $result .= ">";
                  
        foreach my $option ( @options ) {
            $result .= "<option class='foswikiOption' ";
            
            if ( grep (/$option/, @values ) ) {
                $result .= "selected='selected' ";
            }
            
            $result .= ">" . $option . "</option>";
        }
        
        $result .= "</select>";
    }

    return $result;
}

=BEGIN TML

---++ commonTagsHandler($text, $topic, $web, $included, $meta )
   * =$text= - text to be processed
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$included= - Boolean flag indicating whether the handler is
     invoked on an included topic
   * =$meta= - meta-data object for the topic MAY BE =undef=
This handler is called by the code that expands %<nop>MACROS% syntax in
the topic body and in form fields. It may be called many times while
a topic is being rendered.

Only plugins that have to parse the entire topic content should implement
this function. For expanding macros with trivial syntax it is *far* more
efficient to use =Foswiki::Func::registerTagHandler= (see =initPlugin=).

Internal Foswiki macros, (and any macros declared using
=Foswiki::Func::registerTagHandler=) are expanded _before_, and then again
_after_, this function is called to ensure all %<nop>MACROS% are expanded.

*NOTE:* when this handler is called, &lt;verbatim> blocks have been
removed from the text (though all other blocks such as &lt;pre> and
&lt;noautolink> are still present).

*NOTE:* meta-data is _not_ embedded in the text passed to this
handler. Use the =$meta= object.

*Since:* $Foswiki::Plugins::VERSION 2.0

=cut

#sub commonTagsHandler {
#    my ( $text, $topic, $web, $included, $meta ) = @_;
#
#    # If you don't want to be called from nested includes...
#    #   if( $included ) {
#    #         # bail out, handler called from an %INCLUDE{}%
#    #         return;
#    #   }
#
#    # You can work on $text in place by using the special perl
#    # variable $_[0]. These allow you to operate on $text
#    # as if it was passed by reference; for example:
#    # $_[0] =~ s/SpecialString/my alternative/ge;
#}

=begin TML

---++ beforeCommonTagsHandler($text, $topic, $web, $meta )
   * =$text= - text to be processed
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$meta= - meta-data object for the topic MAY BE =undef=
This handler is called before Foswiki does any expansion of its own
internal variables. It is designed for use by cache plugins. Note that
when this handler is called, &lt;verbatim> blocks are still present
in the text.

*NOTE*: This handler is called once for each call to
=commonTagsHandler= i.e. it may be called many times during the
rendering of a topic.

*NOTE:* meta-data is _not_ embedded in the text passed to this
handler.

*NOTE:* This handler is not separately called on included topics.

=cut

#sub beforeCommonTagsHandler {
#    my ( $text, $topic, $web, $meta ) = @_;
#
#    # You can work on $text in place by using the special perl
#    # variable $_[0]. These allow you to operate on $text
#    # as if it was passed by reference; for example:
#    # $_[0] =~ s/SpecialString/my alternative/ge;
#}

=begin TML

---++ afterCommonTagsHandler($text, $topic, $web, $meta )
   * =$text= - text to be processed
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$meta= - meta-data object for the topic MAY BE =undef=
This handler is called after Foswiki has completed expansion of %MACROS%.
It is designed for use by cache plugins. Note that when this handler
is called, &lt;verbatim> blocks are present in the text.

*NOTE*: This handler is called once for each call to
=commonTagsHandler= i.e. it may be called many times during the
rendering of a topic.

*NOTE:* meta-data is _not_ embedded in the text passed to this
handler.

=cut

#sub afterCommonTagsHandler {
#    my ( $text, $topic, $web, $meta ) = @_;
#
#    # You can work on $text in place by using the special perl
#    # variable $_[0]. These allow you to operate on $text
#    # as if it was passed by reference; for example:
#    # $_[0] =~ s/SpecialString/my alternative/ge;
#}

=begin TML

---++ preRenderingHandler( $text, \%map )
   * =$text= - text, with the head, verbatim and pre blocks replaced
     with placeholders
   * =\%removed= - reference to a hash that maps the placeholders to
     the removed blocks.

Handler called immediately before Foswiki syntax structures (such as lists) are
processed, but after all variables have been expanded. Use this handler to
process special syntax only recognised by your plugin.

Placeholders are text strings constructed using the tag name and a
sequence number e.g. 'pre1', "verbatim6", "head1" etc. Placeholders are
inserted into the text inside &lt;!--!marker!--&gt; characters so the
text will contain &lt;!--!pre1!--&gt; for placeholder pre1.

Each removed block is represented by the block text and the parameters
passed to the tag (usually empty) e.g. for
<verbatim>
<pre class='slobadob'>
XYZ
</pre>
</verbatim>
the map will contain:
<pre>
$removed->{'pre1'}{text}:   XYZ
$removed->{'pre1'}{params}: class="slobadob"
</pre>
Iterating over blocks for a single tag is easy. For example, to prepend a
line number to every line of every pre block you might use this code:
<verbatim>
foreach my $placeholder ( keys %$map ) {
    if( $placeholder =~ /^pre/i ) {
        my $n = 1;
        $map->{$placeholder}{text} =~ s/^/$n++/gem;
    }
}
</verbatim>

__NOTE__: This handler is called once for each rendered block of text i.e.
it may be called several times during the rendering of a topic.

*NOTE:* meta-data is _not_ embedded in the text passed to this
handler.

Since Foswiki::Plugins::VERSION = '2.0'

=cut

#sub preRenderingHandler {
#    my( $text, $pMap ) = @_;
#
#    # You can work on $text in place by using the special perl
#    # variable $_[0]. These allow you to operate on $text
#    # as if it was passed by reference; for example:
#    # $_[0] =~ s/SpecialString/my alternative/ge;
#}

=begin TML

---++ postRenderingHandler( $text )
   * =$text= - the text that has just been rendered. May be modified in place.

*NOTE*: This handler is called once for each rendered block of text i.e. 
it may be called several times during the rendering of a topic.

*NOTE:* meta-data is _not_ embedded in the text passed to this
handler.

Since Foswiki::Plugins::VERSION = '2.0'

=cut

#sub postRenderingHandler {
#    my $text = shift;
#    # You can work on $text in place by using the special perl
#    # variable $_[0]. These allow you to operate on $text
#    # as if it was passed by reference; for example:
#    # $_[0] =~ s/SpecialString/my alternative/ge;
#}


=begin TML

---++ modifyHeaderHandler( \%headers, $query )
   * =\%headers= - reference to a hash of existing header values
   * =$query= - reference to CGI query object
Lets the plugin modify the HTTP headers that will be emitted when a
page is written to the browser. \%headers= will contain the headers
proposed by the core, plus any modifications made by other plugins that also
implement this method that come earlier in the plugins list.
<verbatim>
$headers->{expires} = '+1h';
</verbatim>

Note that this is the HTTP header which is _not_ the same as the HTML
&lt;HEAD&gt; tag. The contents of the &lt;HEAD&gt; tag may be manipulated
using the =Foswiki::Func::addToHEAD= method.

*Since:* Foswiki::Plugins::VERSION 2.0

=cut

#sub modifyHeaderHandler {
#    my ( $headers, $query ) = @_;
#}


=begin TML

---++ restMultiTopicSave($session) -> $text

This is the sub which is called called by the =rest= script with multitopicsave.

The parameter is:
   * =$session= - The Foswiki object associated to this session.

Additional parameters can be recovered via the query object in the $session, for example:

my $query = $session->{request};
my $web = $query->{param}->{web}[0];

For more information, check %SYSTEMWEB%.CommandAndCGIScripts#rest

For information about handling error returns from REST handlers, see
Foswiki::Support.Faq1

*Since:* Foswiki::Plugins::VERSION 2.0

=cut

sub restMultiTopicSave {
    my ($session) = @_;
      
    my $query   = Foswiki::Func::getCgiQuery();
    
    my $redirecttopic = $query->param('redirecttopic') || '';
    my $redirectweb = $query->param('redirectweb') || '';
    my $sessionweb = $session->{webName};
    my $sessiontopic = $session->{topicName};
    my %parameters = ();

    ( $redirectweb, $redirecttopic ) =
      Foswiki::Func::normalizeWebTopicName( $redirectweb, $redirecttopic );

    # First we put all the multitopicsavefield parameters in a hash
    # parameters{topicname}{field}=value where value can be an array of
    # values from select fields
    foreach my $key ( $query->param() ) {
        if ( $key =~ /^multitopicsavefield{(.*?)}{(.*?)}$/ ) {

            my $topic = $1;
            my $fieldName = $2;

            $parameters{$topic}{$fieldName} = join(", ", $query->param($key) );
        }
    }

    # Now we traverse each topic and save all the parameters for
    # each topic if they have changed.
    foreach my $topickey ( keys %parameters ) {
        foreach my $fieldName ( keys %{$parameters{$topickey}} ) {
            my $value = $parameters{$topickey}{$fieldName};
           
            my ( $web, $topic ) =
              Foswiki::Func::normalizeWebTopicName( '', $topickey );
            
            my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );
            my $oldValue = $meta->get( 'FIELD', $fieldName )->{'value'};
            
            # Smell: Will this work with multivalue fields? 
            if ( $oldValue ne $value ) {
                unless (
                    Foswiki::Func::checkAccessPermission(
                        'CHANGE', Foswiki::Func::getWikiName(),
                        undef, $topic, $web
                    )
                )
                {
                    next;
                }
                
                $meta->putKeyed( 'FIELD', { name => $fieldName, value => $value } );
                Foswiki::Func::saveTopic($web, $topic, $meta, $text);
            }
        }
    }
   
    my $url = Foswiki::Func::getScriptUrl( $redirectweb, $redirecttopic, 'view' );
    Foswiki::Func::redirectCgiQuery( undef, $url );
    return undef;
}

1;
__END__
# This copyright information applies to the MultiTopicSavePlugin:
#
# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2010 Kenneth Lavrsen and Foswiki Contributors.
# 
# Foswiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# This license applies to MultiTopicSave and to any derivatives.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the root of this distribution.
