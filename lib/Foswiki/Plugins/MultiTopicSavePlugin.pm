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
our $RELEASE = '1.1';

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
    $result .= $params->{_DEFAULT} || "Submit All Changes";
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

    # For single value we leave leading and trailing space. For multiple value
    # fields it is better for the user that we remove leading and trailing
    # spaces as they are most like unwanted in these cases.
    my $value = defined $params->{value} ? $params->{value} : '';
    my @values = map { s/^\s*(.*?)\s*$/$1/; $_; } split( /\s*,\s*/, $value ); 

    # We assume all leading and trailing spaces are unwanted.
    my @options = ();  
    if ( defined $params->{options} ) {
        @options = map { s/^\s*(.*?)\s*$/$1/; $_; } 
                   split( /\s*,\s*/, $params->{options} ); 
    }

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

        # We need a dummy hidden field to be able to send
        # none of the checkboxes selected from the browser
        $result .= "<input type='hidden' name='multitopicsavefield{$targettopic}{$field}' value=''>"
          if ($type eq 'checkbox');
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

        # We need a dummy hidden field to be able to send
        # none of the checkboxes selected from the browser
        $result .= "<input type='hidden' name='multitopicsavefield{$targettopic}{$field}' value=''>";
    }
    elsif ( $type eq 'hidden' ) {
        $result = "<input type='hidden' ";
        $result .= "name='multitopicsavefield{$targettopic}{$field}' ";
        $result .= "value='" . $value . "' />";
    }
    # else if the type is unknown we return nothing

    return $result;
}

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
            my @fieldValues = $query->param($key);

            # Remove empty values, they are most likely dummy values used
            # to indicate that no value in a multiple checkbox or select
            # is selected
            @fieldValues = grep( /.+/, @fieldValues);
            $parameters{$topic}{$fieldName} = join(", ", @fieldValues );
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
