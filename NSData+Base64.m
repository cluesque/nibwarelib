//
//  NSData+Base64.m
//
// Derived from http://colloquy.info/project/browser/trunk/NSDataAdditions.h?rev=1576
// Created by khammond on Mon Oct 29 2001.
// Formatted by Timothy Hatcher on Sun Jul 4 2004.
// Copyright (c) 2001 Kyle Hammond. All rights reserved.
// Original development by Dave Winer.
//

#import "NSData+Base64.h"
#import "NibwareIO.h"

#import <stdlib.h>
#import <Foundation/Foundation.h>

static char encodingTable[64] = {
		'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P',
		'Q','R','S','T','U','V','W','X','Y','Z','a','b','c','d','e','f',
		'g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v',
		'w','x','y','z','0','1','2','3','4','5','6','7','8','9','+','/' };

@implementation NSData (Base64)

+ (NSData *) dataWithBase64EncodedString:(NSString *) string {
	NSData *result = [[NSData alloc] initWithBase64EncodedString:string];
	return [result autorelease];
}

- (id) initWithBase64EncodedString:(NSString *) string {
    int databufoffset = 0;
    unsigned char *databuf = NULL;    
	if( string ) {
		unsigned long ixtext = 0;
		unsigned long lentext = 0;
		unsigned char ch = 0;
		unsigned char inbuf[4], outbuf[4];
		short i = 0, ixinbuf = 0;
		BOOL flignore = NO;
		BOOL flendtext = NO;
		NSData *base64Data = nil;
		const unsigned char *base64Bytes = nil;

		// Convert the string to ASCII data.
		base64Data = [string dataUsingEncoding:NSASCIIStringEncoding];
		base64Bytes = [base64Data bytes];
        lentext = [base64Data length];
        databuf = malloc(lentext);

		while( YES ) {
			if( ixtext >= lentext ) break;
			ch = base64Bytes[ixtext++];
			flignore = NO;

			if( ( ch >= 'A' ) && ( ch <= 'Z' ) ) ch = ch - 'A';
			else if( ( ch >= 'a' ) && ( ch <= 'z' ) ) ch = ch - 'a' + 26;
			else if( ( ch >= '0' ) && ( ch <= '9' ) ) ch = ch - '0' + 52;
			else if( ch == '+' ) ch = 62;
			else if( ch == '=' ) flendtext = YES;
			else if( ch == '/' ) ch = 63;
			else flignore = YES; 
   
			if( ! flignore ) {
				short ctcharsinbuf = 3;
				BOOL flbreak = NO;

				if( flendtext ) {
					if( ! ixinbuf ) break;
					if( ( ixinbuf == 1 ) || ( ixinbuf == 2 ) ) ctcharsinbuf = 1;
					else ctcharsinbuf = 2;
					ixinbuf = 3;
					flbreak = YES;
				}

				inbuf [ixinbuf++] = ch;

				if( ixinbuf == 4 ) {
					ixinbuf = 0;
					outbuf [0] = ( inbuf[0] << 2 ) | ( ( inbuf[1] & 0x30) >> 4 );
					outbuf [1] = ( ( inbuf[1] & 0x0F ) << 4 ) | ( ( inbuf[2] & 0x3C ) >> 2 );
					outbuf [2] = ( ( inbuf[2] & 0x03 ) << 6 ) | ( inbuf[3] & 0x3F );

					for( i = 0; i < ctcharsinbuf; i++ ) {
                        databuf[databufoffset++] = outbuf[i];
                    }

				}

				if( flbreak )  break;
			}
		}
	}

    if (databufoffset > 0) {
        self = [self initWithBytes:databuf length:databufoffset];
    } else {
        self = [self init];
    }
    if (databuf)
        free(databuf);
	return self;
}

- (NSString*) base64EncodingWithLineLength:(unsigned int)lineLength
{
    NibwareDiskBackedBuffer *buf = [[NibwareDiskBackedBuffer alloc] initWithMaxSize:16384 capacity:256];
    
    [self base64EncodingWithLineLength:lineLength toOutputStream:buf];
    
	NSString *res = [buf inputString:NSASCIIStringEncoding];
    [buf release];
    return res;
}

- (NSInteger) base64EncodingWithLineLength:(unsigned int)lineLength toOutputStream:(id<NibwareOutputStream>)stream
{
	const unsigned char	*bytes = [self bytes];
	unsigned long ixtext = 0;
	unsigned long lentext = [self length];
	long ctremaining = 0;
	unsigned char inbuf[3], outbuf[4];
	short i = 0;
	short charsonline = 0, ctcopy = 0;
	unsigned long ix = 0;
    
    NSMutableData *data = [NSMutableData data];
    
    int returnLength = 0;
    
	while( YES ) {
		ctremaining = lentext - ixtext;
		if( ctremaining <= 0 ) break;
        
		for( i = 0; i < 3; i++ ) {
			ix = ixtext + i;
			if( ix < lentext ) inbuf[i] = bytes[ix];
			else inbuf [i] = 0;
		}
        
		outbuf [0] = (inbuf [0] & 0xFC) >> 2;
		outbuf [1] = ((inbuf [0] & 0x03) << 4) | ((inbuf [1] & 0xF0) >> 4);
		outbuf [2] = ((inbuf [1] & 0x0F) << 2) | ((inbuf [2] & 0xC0) >> 6);
		outbuf [3] = inbuf [2] & 0x3F;
		ctcopy = 4;
        
		switch( ctremaining ) {
            case 1: 
                ctcopy = 2; 
                break;
            case 2: 
                ctcopy = 3; 
                break;
		}
        
        [data setLength:0];
		for( i = 0; i < ctcopy; i++ ) {
            [data appendBytes:&encodingTable[outbuf[i]] length:1];
        }
        
		for( i = ctcopy; i < 4; i++ ) {
            unsigned char eq = '=';
            [data appendBytes:&eq length:1];
        }
        
		ixtext += 3;
		charsonline += 4;
        
		if( lineLength > 0 ) {
			if (charsonline >= lineLength) {
				charsonline = 0;
                
                unsigned char newline = '\n';
                [data appendBytes:&newline length:1];
			}
		}
        
        [stream appendData:data];
        returnLength += [data length];
        [data setLength:0];
	}
    
	return returnLength;
}


- (NSInteger) base64EncodingWithLineLength:(unsigned int)lineLength toFileHandle:(NSFileHandle*)handle
{
    NibwareFileOutputStream *stream = [[NibwareFileOutputStream alloc] initWithFile:handle];
    
    NSInteger size = [self base64EncodingWithLineLength:lineLength toOutputStream:stream];
    
    [stream release];
    
	return size;
}


@end
