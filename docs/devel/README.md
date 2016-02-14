Developer FAQ
========

## How is back compatibility handled?

### What about supporting a span of versions?

Ans:  Spanning more than one version of a component will means a proliferation of test cases, so the recommendation is to be a point in time and not 'this latest version and that slightly older version'.

This will reduce the code test sets to a single configuration (tested in many ways anyways).


### How are features and functionality removed or depreceated?

Ans: When a specific technique or function is removed one should:
#### create a ticket describing the change to be performed
#### depending on how invasive the change is, remove the elements or
#### if desiring a 'sunset' of the feature comment out the dependant lines with:
##### #Deprecated:YYYY-MM-DD:TODO: [remove next release|short phrase of action here]

# Style Guide

## How are file paths as variables referred to -- trailing slash or no trailing slash?
### No trailing slash. /this/is/the/way  /not/this/way/  

## How should I make changes to configuraiton files that are sustainable and can cross version updates?
####  This is a hard one.  It's more of a process to choose a technique than 'always do it this way'

In our case we have various files but ususally they are:

.properties name value pairs
	- these can be updated in two ways:
	-- using SED to tweak the file in place
		--- useful if something is just 'uncomment this and go'
	-- concatenating something at the end of a file
		--- an ok approach and a bit more free-form.  
		----  Risks: Sacrifices readability
		----  duplicate values may occur unknowingly.

.xml structured XML files 
	- updating these files usually uses:
	-- SED for surgical replacement finding a discrete string
	-- templating the file completely with one of our own
	-- applying a diff shipped in our code against a known distribution
	-- RISKS:
	--- templating is preferred and diffs have been used but are more fragile
	--- TBD -- more to come

## How do you handle files that have dependancies? Fetch them in real time or bundle them with the zip of the installer?

### This is a challenge as it is a balancing act between 'simply update things by changing a version number' and 'I have to do a build and test because some small library changed'.

Once again, it's a process to analyze the material sway and impact against the overall stability of the build.
The preference of we the maintainers is to have a build that is resilient to failure and strive for a build that WARNS of errors on a customization but installs the IDP.  So a 'graceful' fail scenario that results as best possible in an IdP installation.

Wherever possible:
- Bundle the dependancy as long as it doesn't violate the intent of the licencing.
- Alert the installer that there a number of dependancies being automatically installed and highlight any significant assumptions being made.


## What's the practice around backing up files?

### It is strongly recommended to backup the file in place with a consistent prefix using the 'fileBkpPostfix' variable prefixed with a dot.  This allows review post installation against what was done and what was in the distribution.



