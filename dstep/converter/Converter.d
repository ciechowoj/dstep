/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Oct 6, 2011
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.converter.Converter;

import clang.c.index;
import clang.TranslationUnit;

class Converter
{
	TranslationUnit translationUnit;
	
	this (TranslationUnit translationUnit)
	{
		this.translationUnit = translationUnit;
	}
	
	void convert ()
	{
		
	}
}