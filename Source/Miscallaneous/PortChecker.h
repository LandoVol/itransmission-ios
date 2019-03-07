/******************************************************************************
 * $Id: PortChecker.h 9844 2010-01-01 21:12:04Z livings124 $
 *
 * Copyright (c) 2006-2010 Transmission authors and contributors
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 *****************************************************************************/

typedef enum
{
    PORT_STATUS_CHECKING,
    PORT_STATUS_OPEN,
    PORT_STATUS_CLOSED,
    PORT_STATUS_ERROR
} port_status_t;

@class PortChecker;

@protocol PortCheckerDelegate <NSObject>
- (void)portCheckerDidFinishProbing:(PortChecker*)c;
@end

@interface PortChecker : NSObject
{    
    NSObject<PortCheckerDelegate> *fDelegate;
    port_status_t fStatus;
    
    NSURLConnection * fConnection;
    NSMutableData * fPortProbeData;

    NSInteger fPortNumber;
    NSTimer * fTimer;
}
@property (nonatomic, assign) NSInteger portToCheck;

- (id) initForPort: (NSInteger) portNumber delay: (BOOL) delay withDelegate: (id) delegate;
- (void) cancelProbe;

- (port_status_t) status;

@end