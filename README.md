FLOSync
=======

This is our iOS implementation of a two-way syncing algorithm for DropBox!

What it is
----------

FLOSync synchronizes files in your app's documents directory with dropbox.

How to use it
-------------

Once you've included the DropBox SDK in your project, simply call the following method to invoke the sync.

	[FLOSync Sync];

Dependencies
------------
This class uses the ConciseKit headers: (https://github.com/petejkim/ConciseKit)

About
-----

The methodology and design behind this class was inspired from Chris Hulbert's CHBgDropboxSync. I wrote this class to reduce the number of calls made to loadMetadata and to objectify the process a little more.

You can find CHBgDropboxSync [here](https://github.com/chrishulbert/CHBgDropboxSync). 