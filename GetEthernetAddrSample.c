/*
    File:		GetEthernetAddrAllSample.c
	
    Description:	This sample demonstrates how to use IOKitLib to find all of the Ethernet MAC address
                        of the system when there are more than one interface present.
                
    Copyright:		© Copyright 2003 Apple Computer, Inc. All rights reserved.
	
    Disclaimer:		IMPORTANT:  This Apple software is supplied to you by Apple Computer, Inc.
                        ("Apple") in consideration of your agreement to the following terms, and your
                        use, installation, modification or redistribution of this Apple software
                        constitutes acceptance of these terms.  If you do not agree with these terms,
                        please do not use, install, modify or redistribute this Apple software.

                        In consideration of your agreement to abide by the following terms, and subject
                        to these terms, Apple grants you a personal, non-exclusive license, under Apple’s
                        copyrights in this original Apple software (the "Apple Software"), to use,
                        reproduce, modify and redistribute the Apple Software, with or without
                        modifications, in source and/or binary forms; provided that if you redistribute
                        the Apple Software in its entirety and without modifications, you must retain
                        this notice and the following text and disclaimers in all such redistributions of
                        the Apple Software.  Neither the name, trademarks, service marks or logos of
                        Apple Computer, Inc. may be used to endorse or promote products derived from the
                        Apple Software without specific prior written permission from Apple.  Except as
                        expressly stated in this notice, no other rights or licenses, express or implied,
                        are granted by Apple herein, including but not limited to any patent rights that
                        may be infringed by your derivative works or by other works in which the Apple
                        Software may be incorporated.

                        The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO
                        WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED
                        WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A PARTICULAR
                        PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND OPERATION ALONE OR IN
                        COMBINATION WITH YOUR PRODUCTS.

                        IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR
                        CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
                        GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
                        ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION
                        OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER UNDER THEORY OF CONTRACT, TORT
                        (INCLUDING NEGLIGENCE), STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN
                        ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
				
	Change History (most recent first):
        
            <1>	 	02/19/01	New sample.
        
*/

#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <paths.h>
#include <sysexits.h>
#include <sys/param.h>
#include "GetEthernetAddrSample.h"

//typedef struct EthernetData EnetData;

static kern_return_t FindEthernetInterfaces(io_iterator_t *matchingServices);
static kern_return_t GetEthernetData(io_iterator_t intfIterator, EnetData *edata, UInt32 *numEntries);

// Returns an iterator across all known Ethernet interfaces. Caller is responsible for
// releasing the iterator when iteration is complete.
static kern_return_t FindEthernetInterfaces(io_iterator_t *matchingServices)
{
    kern_return_t		kernResult; 
    mach_port_t			masterPort;
    CFMutableDictionaryRef	classesToMatch;

/*! @function IOMasterPort
    @abstract Returns the mach port used to initiate communication with IOKit.
    @discussion Functions that don't specify an existing object require the IOKit master port to be passed. This function obtains that port.
    @param bootstrapPort Pass MACH_PORT_NULL for the default.
    @param masterPort The master port is returned.
    @result A kern_return_t error code. */

    kernResult = IOMasterPort(MACH_PORT_NULL, &masterPort);
    if (KERN_SUCCESS != kernResult)
        printf("IOMasterPort returned %d\n", kernResult);
        
/*! @function IOServiceMatching
    @abstract Create a matching dictionary that specifies an IOService class match.
    @discussion A very common matching criteria for IOService is based on its class. IOServiceMatching will create a matching dictionary that specifies any IOService of a class, or its subclasses. The class is specified by C-string name.
    @param name The class name, as a const C-string. Class matching is successful on IOService's of this class or any subclass.
    @result The matching dictionary created, is returned on success, or zero on failure. The dictionary is commonly passed to IOServiceGetMatchingServices or IOServiceAddNotification which will consume a reference, otherwise it should be released with CFRelease by the caller. */

    // Ethernet interfaces are instances of class kIOEthernetInterfaceClass
    classesToMatch = IOServiceMatching(kIOEthernetInterfaceClass);

    // Note that another option here would be:
    // classesToMatch = IOBSDMatching("enX");
    // where X is a number from 0 to the number of Ethernet interfaces on the system - 1.
    
    if (classesToMatch == NULL)
        printf("IOServiceMatching returned a NULL dictionary.\n");
    
    /*! @function IOServiceGetMatchingServices
        @abstract Look up registered IOService objects that match a matching dictionary.
        @discussion This is the preferred method of finding IOService objects currently registered by IOKit. IOServiceAddNotification can also supply this information and install a notification of new IOServices. The matching information used in the matching dictionary may vary depending on the class of service being looked up.
        @param masterPort The master port obtained from IOMasterPort().
        @param matching A CF dictionary containing matching information, of which one reference is consumed by this function. IOKitLib can contruct matching dictionaries for common criteria with helper functions such as IOServiceMatching, IOOpenFirmwarePathMatching.
        @param existing An iterator handle is returned on success, and should be released by the caller when the iteration is finished.
        @result A kern_return_t error code. */

    kernResult = IOServiceGetMatchingServices(masterPort, classesToMatch, matchingServices);    
    if (KERN_SUCCESS != kernResult)
        printf("IOServiceGetMatchingServices returned %d\n", kernResult);
    
    return kernResult;
}

#define kBSDName "BSD Name"
    
// Given an iterator across a set of Ethernet interfaces, return the MAC address of the first one.
// If no interfaces are found the MAC address is set to an empty string.
static kern_return_t GetEthernetData(io_iterator_t intfIterator, EnetData *edata, UInt32 *numEntries)
{
    io_object_t		intfService;
    io_object_t		controllerService;	// parent of intfService
    io_object_t		parentService;		// parent of controllerService where built-in property exists
    kern_return_t	kernResult = KERN_FAILURE;
    UInt32		maxEntriesToFind;
            
/*! @function IOIteratorNext
    @abstract Returns the next object in an iteration.
    @discussion This function returns the next object in an iteration, or zero if no more remain or the iterator is invalid.
    @param iterator An IOKit iterator handle.
    @result If the iterator handle is valid, the next element in the iteration is returned, otherwise zero is returned. The element should be released by the caller when it is finished. */

    // save the size of the EnetData structure so that we can limit the number of entries that are found
    maxEntriesToFind = *numEntries;
    *numEntries = 0;
    while ((intfService = IOIteratorNext(intfIterator)) && (*numEntries < maxEntriesToFind))
    {
        CFTypeRef	bsdName;
        CFTypeRef	MACAddressAsCFData;

        // Initialize the bsdName field
        bzero(edata[*numEntries].bsdName, sizeof(edata[*numEntries].bsdName));
        
        bsdName = IORegistryEntryCreateCFProperty(intfService, CFSTR(kBSDName),
                                                    kCFAllocatorDefault, 0);
        if (bsdName)
        {
            CFStringGetCString(bsdName, (edata[*numEntries].bsdName), 
                                sizeof(edata[*numEntries].bsdName), kCFStringEncodingMacRoman);
            CFRelease(bsdName);
        }

        // Initialize the returned address
        bzero(edata[*numEntries].macAddress, kIOEthernetAddressSize);

        // IONetworkControllers can't be found directly by the IOServiceGetMatchingServices call, 
        // matching mechanism. So we've found the IONetworkInterface and will get its parent controller
        // by asking for it specifically.
        
        kernResult = IORegistryEntryGetParentEntry( intfService,
                                                    kIOServicePlane,
                                                    &controllerService );

        if (KERN_SUCCESS != kernResult)
            printf("IORegistryEntryGetParentEntry returned 0x%08x\n", kernResult);
        else 
        {
/*! @function IORegistryEntryCreateCFProperty
    @abstract Create a CF representation of a registry entry's property.
    @discussion This function creates an instantaneous snapshot of a registry entry property, creating a CF container analogue in the caller's task. Not every object available in the kernel is represented as a CF container; currently OSDictionary, OSArray, OSSet, OSSymbol, OSString, OSData, OSNumber, OSBoolean are created as their CF counterparts. 
    @param entry The registry entry handle whose property to copy.
    @param key A CFString specifying the property name.
    @param allocator The CF allocator to use when creating the CF container.
    @param options No options are currently defined.
    @result A CF container is created and returned the caller on success. The caller should release with CFRelease. */

            MACAddressAsCFData = IORegistryEntryCreateCFProperty( controllerService,
                                                                  CFSTR(kIOMACAddress),
                                                                  kCFAllocatorDefault,
                                                                  0);
            if (MACAddressAsCFData)
            {
//                CFShow(MACAddressAsCFData);
                CFDataGetBytes(MACAddressAsCFData, CFRangeMake(0, kIOEthernetAddressSize), edata[*numEntries].macAddress);
//                BlockMove(enetAddr, edata[gNumEntries].macAddress, kIOEthernetAddressSize);
                CFRelease(MACAddressAsCFData);
            }            
            
            /* code to check whether the ethernet device is built-in by looking at the parent for a
               built-in property - need to look at the parent service to controller service
               to find this property.
            */
            
            kernResult = IORegistryEntryGetParentEntry( controllerService,
                                                        kIOServicePlane,
                                                        &parentService );
            if (KERN_SUCCESS != kernResult)
                printf("IORegistryEntryGetParentEntry for parentService returned 0x%08x\n", kernResult);
            else 
            {
                CFTypeRef	builtinAsCFData; 
            	builtinAsCFData = IORegistryEntryCreateCFProperty( parentService,
                                                                  CFSTR("built-in"),
                                                                  kCFAllocatorDefault,
                                                                  0);
                if (builtinAsCFData)
                {
                    // property exists so set the true bit
                    edata[*numEntries].isBuiltIn = TRUE;
                    CFRelease(builtinAsCFData);
//                    printf("built-in device found\n");
                }
                else
                {
                    edata[*numEntries].isBuiltIn = FALSE;
                }

                (void) IOObjectRelease(parentService);
            }
        
        /*! @function IOObjectRelease
            @abstract Releases an object handle previously returned by IOKitLib.
            @discussion All objects returned by IOKitLib should be released with this function when access to them is no longer needed. Using the object after it has been released may or may not return an error, depending on how many references the task has to the same object in the kernel.
            @param object The IOKit object to release.
            @result A kern_return_t error code. */
                
            (void) IOObjectRelease(controllerService);
        }
        
        // increment the counter
        (*numEntries)++;
        
    }

    // We have sucked this service dry of information so release it now.
    (void) IOObjectRelease(intfService);
        
    return kernResult;
}

/*
    GetEthernetAddress returns the following info in the EnetData structure
    1. the ethernet address
    2. the bsd name
    3. a boolean indicating whether the ethernet device is built-in or not
    
    Input:
    The (EnetData*) parameter is a pointer to an EnetData array of *numEntries
    in array elements.
    
    Output: the numEntries value is modified to reflect the number of Enet items 
    found.
*/
int GetEthernetAddressInfo(EnetData *edata, UInt32 *numEntries)
{
    kern_return_t	kernResult = KERN_SUCCESS; // on PowerPC this is an int (4 bytes)
/*
 *	error number layout as follows (see mach/error.h and IOKitLib/IOReturn.h):
 *
 *	hi		 		       lo
 *	| system(6) | subsystem(12) | code(14) |
 */

    io_iterator_t	intfIterator;
 
    kernResult = FindEthernetInterfaces(&intfIterator);
    if (KERN_SUCCESS != kernResult)
        printf("FindEthernetInterfaces returned 0x%08x\n", kernResult);
    else 
    {
        kernResult = GetEthernetData(intfIterator, edata, numEntries);

        if (KERN_SUCCESS != kernResult)
            printf("GetEthernetData returned 0x%08x\n", kernResult);
    }

    IOObjectRelease(intfIterator);	// Release the iterator.
        
    return kernResult;
}
