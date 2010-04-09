//----------------------------------------------------------------------------------------
//	SvnInterface.m - Interface to Subversion libraries
//
//	Copyright © Chris, 2003 - 2010.  All rights reserved.
//----------------------------------------------------------------------------------------

#import "MyApp.h"
#import "MySVN.h"
#import "Tasks.h"
#import "SvnInterface.h"
#import "svn_config.h"
#import "svn_fs.h"
#import "svn_auth.h"
#import "NSString+MyAdditions.h"


#define	SvnPush(array, obj)		((*(typeof(obj)*) apr_array_push(array)) = (obj))


//----------------------------------------------------------------------------------------

@implementation SvnException

- (id) init: (SvnError) err
{
	self = [super init];
	if (self)
	{
		fError = err;
	}

	return self;
}


//----------------------------------------------------------------------------------------

- (void) dealloc
{
	svn_error_clear(fError);
	[super dealloc];
}


//----------------------------------------------------------------------------------------

- (SvnError) error
{
	return fError;
}


//----------------------------------------------------------------------------------------

- (NSString*) message
{
	return fError ? UTF8(fError->message) : @"";
}

@end	// SvnException


//----------------------------------------------------------------------------------------

void
SvnDoThrow (SvnError err)
{
	@throw [[SvnException alloc] init: err];
}


//----------------------------------------------------------------------------------------

void
SvnDoReport (SvnError err)
{
	// TO_DO: Show alert
#if qDebug
	DbgSvnPrint(err);
#elif 0
	svn_handle_error2(err, stderr, FALSE, kAppName);
#endif
}


//----------------------------------------------------------------------------------------
#pragma mark -
//----------------------------------------------------------------------------------------
// Returns TRUE if the Subversion lib was initialized successfully.

BOOL
SvnInitialize ()
{
	extern apr_status_t apr_initialize(void) WEAK_IMPORT_ATTRIBUTE;
	extern svn_error_t* svn_fs_initialize(apr_pool_t* pool) WEAK_IMPORT_ATTRIBUTE;
	extern svn_error_t* svn_ver_check_list(const svn_version_t* my_version,
								const svn_version_checklist_t* checklist) WEAK_IMPORT_ATTRIBUTE;

	#define	VERS_NUM(a,b,c)		((a) * 1000000 + (b) * 1000 + (c))
	#define	VERS_EQ(v1,v2)		(((v1) / 1) == ((v2) / 1))		// Could be '/ 1000'
	static UInt32 libVersion = 0;
	const UInt32 kMinVersion = VERS_NUM(1,4,0), kMaxVersion = VERS_NUM(1,999,999);
	const UInt32 toolVersion = [[NSApp delegate] svnVersionNum];

	if (toolVersion < kMinVersion || toolVersion > kMaxVersion)
	{
	//	dprintf("toolVersion=%u => FALSE", toolVersion);
		return FALSE;
	}
	else if (!libVersion)
	{
		// Initialize the APR & SVN libraries.
		if (apr_initialize != NULL && svn_fs_initialize != NULL && svn_ver_check_list != NULL)
		{
			NSLocale* locale = [NSLocale currentLocale];
			char buf[32];
			if (ToUTF8([NSString stringWithFormat: @"%@_%@.UTF-8",
							[locale objectForKey: NSLocaleLanguageCode],
							[locale objectForKey: NSLocaleCountryCode]],
						buf, sizeof(buf)))
			{
			//	dprintf("locale='%s'", buf);
				setlocale(LC_ALL, buf);
				if (apr_initialize() == APR_SUCCESS)
				{
					static const svn_version_checklist_t checklist[] = {
					//	{ "apr",        apr_version        },
						{ "svn_client", svn_client_version },
						{ "svn_fs",     svn_fs_version     },
						{ "svn_subr",   svn_subr_version   },
					//	{ "svn_wc",     svn_wc_version     },
						{ NULL, NULL }
					};

					SVN_VERSION_DEFINE(myV);
					Assert(kMinVersion <= VERS_NUM(myV.major, myV.minor, myV.patch));
					Assert(kMaxVersion >= VERS_NUM(myV.major, myV.minor, myV.patch));

					SvnError err = svn_ver_check_list(&myV, checklist);
					if (err == NULL)
					{
						const svn_version_t* libV = svn_client_version();
						if (libV != NULL)
							libVersion = VERS_NUM(libV->major, libV->minor, libV->patch);
					}
				//	dprintf("myVersion=%u.%u.%u hasLib=%d",
				//			myV.major, myV.minor, myV.patch, VERS_EQ(libVersion, toolVersion));
				#if qDebug
					if (err)
						DbgSvnPrint(err);
				#endif
				}
				else
					dprintf("apr_initialize() != APR_SUCCESS", 0);
			}
		}
		else
			dprintf("apr_initialize=0x%lX svn_fs_initialize=0x%lX svn_ver_check_list=0x%lX",
					apr_initialize, svn_fs_initialize, svn_ver_check_list);
		if (!libVersion)
			libVersion = VERS_NUM(0,0,1);
	}
	//dprintf("toolVersion=%u libVersion=%u => hasLib=%d",
	//		toolVersion, libVersion, VERS_EQ(libVersion, toolVersion));

	return VERS_EQ(libVersion, toolVersion);
}


//----------------------------------------------------------------------------------------
// Returns TRUE if the Subversion lib is wanted & was initialized successfully.

BOOL
SvnWantAndHave ()
{
	NSString* const kDontWantSvnLib = @"useOldParsingMethod";
	if (GetPreferenceBool(kDontWantSvnLib))
		return FALSE;		// Don't want svn lib

	BOOL haveLib = SvnInitialize();

	if (!haveLib)			// Can't have svn lib (so don't want it)
	{
		SetPreference(kDontWantSvnLib, kNSTrue);
	}

	return haveLib;
}


//----------------------------------------------------------------------------------------
// Create top-level memory pool

SvnPool
SvnNewPool ()
{
	return svn_pool_create(NULL);
}


//----------------------------------------------------------------------------------------

void
SvnDeletePool (SvnPool pool)
{
	svn_pool_destroy(pool);
}


//----------------------------------------------------------------------------------------

SvnRevNum
SvnRevNumFromString (NSString* revision)
{
	if (revision == nil)
		return SVN_INVALID_REVNUM;
	if ([revision isEqualToString: @"HEAD"])
		return INT_MAX;
	return [revision intValue];
}


//----------------------------------------------------------------------------------------

NSString*
SvnRevNumToString (SvnRevNum rev)
{
	return SVN_IS_VALID_REVNUM(rev) ? [NSString stringWithFormat: @"%d", rev] : @"";
}


//----------------------------------------------------------------------------------------

NSString*
SvnStatusToString (SvnWCStatusKind kind)
{
	switch (kind)
	{
		case svn_wc_status_none:		return @" ";
		case svn_wc_status_unversioned:	return @"?";
		case svn_wc_status_normal:		return @" ";
		case svn_wc_status_added:		return @"A";
		case svn_wc_status_missing:		return @"!";
		case svn_wc_status_deleted:		return @"D";
		case svn_wc_status_replaced:	return @"R";
		case svn_wc_status_modified:	return @"M";
		case svn_wc_status_merged:		return @"G";
		case svn_wc_status_conflicted:	return @"C";
		case svn_wc_status_ignored:		return @"I";
		case svn_wc_status_obstructed:	return @"~";
		case svn_wc_status_external:	return @"X";
		case svn_wc_status_incomplete:	return @"!";
	}

	return @"?";	// ???
}


//----------------------------------------------------------------------------------------

static const char*
CopyString (NSString* strObj, SvnPool pool)
{
	const char* str = NULL;
	char buf[256];
	if (strObj && [strObj length] &&
		[strObj getCString: buf maxLength: sizeof(buf) encoding: NSUTF8StringEncoding])
	{
		str = apr_pstrdup(pool, buf);
	}

	return str;
}


//----------------------------------------------------------------------------------------

static void
SetParam (SvnAuth auth, const char* name, const void* value)
{
//	dprintf("(0x%X, name='%s', value='%s')", auth, name, value);
	if (value)
		svn_auth_set_parameter(auth, name, value);
}


//----------------------------------------------------------------------------------------
// This implements 'svn_auth_ssl_server_trust_prompt_func_t'.

static SvnError
SvnAuth_ssl_server_trust_prompt (svn_auth_cred_ssl_server_trust_t** cred_p,
								 void* baton,
								 const char* realm,
								 apr_uint32_t failures,
								 const svn_auth_ssl_server_cert_info_t* cert_info,
								 SvnBool may_save,
								 SvnPool pool)
{
	#pragma unused(baton)
//	const id delegate = (id) baton;
	NSMutableString* msg = [NSMutableString string];
	#define	APPEND_MSG(m)	[msg appendString: UTF_8_16("\xE2\x80\xA2 " m, "\u2022 " m)]
	if (failures & SVN_AUTH_SSL_UNKNOWNCA)
		APPEND_MSG("The certificate is not issued by a trusted authority.\n"
				   "   Use the fingerprint to validate the certificate manually!\n");

	if (failures & SVN_AUTH_SSL_CNMISMATCH)
		APPEND_MSG("The certificate hostname does not match.\n");

	if (failures & SVN_AUTH_SSL_NOTYETVALID)
		APPEND_MSG("The certificate is not yet valid.\n");

	if (failures & SVN_AUTH_SSL_EXPIRED)
		APPEND_MSG("The certificate has expired.\n");

	if (failures & SVN_AUTH_SSL_OTHER)
		APPEND_MSG("The certificate has an unknown error.\n");
	#undef	APPEND_MSG

	[msg appendFormat: @"Certificate information:\n"
						" - Hostname: %s\n"
						" - Valid: from %s until %s\n"
						" - Issuer: %s\n"
						" - Fingerprint: %s",
						cert_info->hostname,
						cert_info->valid_from,
						cert_info->valid_until,
						cert_info->issuer_dname,
						cert_info->fingerprint];

	// Modally ask user to Accept Permanently, Temporarily or Reject the certificate
	NSAlert* alert = [[NSAlert alloc] init];
	[alert setMessageText: [NSString stringWithFormat:
								@"Error validating server certificate for %C%s%C.",
								0x2018, realm, 0x2019]];
	const BOOL force_save = TRUE;	// Disable 'Accept Temporarily' for now
	if (force_save)
		[alert addButtonWithTitle: @"Accept"];
	else
	{
		if (may_save)
			[alert addButtonWithTitle: @"Accept Permanently"];
		[alert addButtonWithTitle: @"Accept Temporarily"];
	}
	[alert addButtonWithTitle: @"Reject"];
	[alert setInformativeText: msg];
	[alert setAlertStyle: NSInformationalAlertStyle];

	BOOL makeCred = TRUE;
	switch ([alert runModal])
	{
		case NSAlertFirstButtonReturn:	// Accept Permanently/Temporarily
			break;

		case NSAlertSecondButtonReturn:
			if (!force_save && may_save)
			{
				may_save = FALSE;		// Accept Temporarily
				break;
			}
			// fall through

		case NSAlertThirdButtonReturn:	// Reject
			makeCred = FALSE;
			break;
	}
	[alert release];

//	dprintf("makeCred=%d  may_save=%d  failures=0x%X", makeCred, may_save, failures);
	svn_auth_cred_ssl_server_trust_t* cred = NULL;
	if (makeCred)
	{
		cred = apr_pcalloc(pool, sizeof(*cred));
		cred->may_save          = force_save || may_save;
		cred->accepted_failures = failures;
	}
	*cred_p = cred;

	return SVN_NO_ERROR;
}


//----------------------------------------------------------------------------------------

static SvnAuth
SvnSetupAuthentication (id delegate, SvnPool pool)
{
	SvnArray providers = SvnNewArray(pool, 8, sizeof(SvnAuthProvider));

	#define	Push()		((SvnAuthProvider*) apr_array_push(providers))

	svn_auth_get_keychain_simple_provider(Push(), pool);
	svn_auth_get_simple_provider(Push(), pool);
	svn_auth_get_username_provider(Push(), pool);

	// The server-cert, client-cert, and client-cert-password providers.
	svn_auth_get_ssl_server_trust_file_provider(Push(), pool);
	svn_auth_get_ssl_client_cert_file_provider(Push(), pool);
	svn_auth_get_ssl_client_cert_pw_file_provider(Push(), pool);

#if 0
	svn_auth_get_simple_prompt_provider(Push(), SvnAuth_simple_prompt,
										delegate, kSvnRetryLimit, pool);
	svn_auth_get_username_prompt_provider(Push(), SvnAuth_username_prompt,
										  delegate, kSvnRetryLimit, pool);
#endif

	// Three ssl prompt providers, for server-certs, client-certs, and client-cert-passphrases.
	svn_auth_get_ssl_server_trust_prompt_provider(Push(), SvnAuth_ssl_server_trust_prompt,
												  delegate, pool);
#if 0
	svn_auth_get_ssl_client_cert_prompt_provider(Push(), SvnAuth_ssl_client_cert_prompt,
												 delegate, kSvnRetryLimit, pool);
	svn_auth_get_ssl_client_cert_pw_prompt_provider(Push(), SvnAuth_ssl_client_cert_pw_prompt,
													delegate, kSvnRetryLimit, pool);
#endif

	#undef	Push

	SvnAuth auth_baton = NULL;
	svn_auth_open(&auth_baton, providers, pool);

	if (delegate)
	{
		SetParam(auth_baton, SVN_AUTH_PARAM_DEFAULT_USERNAME, CopyString([delegate user], pool));
		SetParam(auth_baton, SVN_AUTH_PARAM_DEFAULT_PASSWORD, CopyString([delegate pass], pool));
	}
//	SetParam(auth_baton, SVN_AUTH_PARAM_NON_INTERACTIVE, "");
	SetParam(auth_baton, SVN_AUTH_PARAM_DONT_STORE_PASSWORDS, "");
//	SetParam(auth_baton, SVN_AUTH_PARAM_NO_AUTH_CACHE, "");

	return auth_baton;
}


//----------------------------------------------------------------------------------------

struct SvnEnv
{
	SvnPool		pool;
	SvnClient	client;
};


//----------------------------------------------------------------------------------------

SvnClient
SvnSetupClient (SvnEnv** envRef, SvnInterface* delegate)
{
	Assert(envRef != NULL);
	SvnEnv* env = *envRef;
	if (env == NULL)
	{
		// Create top-level memory pool.
		SvnPool pool = SvnNewPool();

		*envRef = env = apr_pcalloc(pool, sizeof(SvnEnv));
		env->pool = pool;

		// Initialize the FS library.
		SvnThrowIf(svn_fs_initialize(pool));

		// Make sure the ~/.subversion run-time config files exist
		SvnThrowIf(svn_config_ensure(NULL, pool));

		// Initialize and allocate the client_ctx object.
		SvnThrowIf(svn_client_create_context(&env->client, pool));
		SvnClient ctx = env->client;

		// Load the run-time config file into a hash
		SvnThrowIf(svn_config_get_config(&ctx->config, NULL, pool));

		ctx->auth_baton = SvnSetupAuthentication(delegate, pool);

		// Set the log message callback function.
	//	ctx->log_msg_func2 = SvnGetLogMessage;

		// Set up our cancellation support.
	//	ctx->cancel_func = SvnCheckCancel;
	}

	return env->client;
}


//----------------------------------------------------------------------------------------

void
SvnEndClient (SvnEnv* env)
{
	if (env && env->pool)
		SvnDeletePool(env->pool);
}


//----------------------------------------------------------------------------------------

SvnPool
SvnGetPool (SvnEnv* env)
{
	Assert(env && env->pool);
	return env ? env->pool : NULL;
}


//----------------------------------------------------------------------------------------

static const NSTimeInterval kDefaultMaxRunTime = 30;

static inline NSTimeInterval RunTime (NSTimeInterval t) { return t ? t : kDefaultMaxRunTime; }

static inline NSString* NewString_	(NSData* data)
{ return [[[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding] autorelease]; }


//----------------------------------------------------------------------------------------

int
SvnRun (NSArray* args, NSData** stdOut, NSData** stdErr, NSTimeInterval maxTime)
{
	int status = -1;
	*stdOut = *stdErr = nil;
	@try
	{
		NSTask* const task = [[NSTask new] autorelease];
		[task setEnvironment: [Task createEnvironment: NO]];	
		[task setLaunchPath: SvnCmdPath()];
		[task setArguments: args];
		NSPipe* pipe;
		[task setStandardOutput: pipe = [NSPipe pipe]];
		NSFileHandle* const outf = [pipe fileHandleForReading];
		[task setStandardError:  pipe = [NSPipe pipe]];
		NSFileHandle* const errf = [pipe fileHandleForReading];
		[task launch];

		NSMutableData* const outData = [NSMutableData data],
						   * errData = [NSMutableData data];
		*stdOut = outData;
		*stdErr = errData;
		const UTCTime endTime = CFAbsoluteTimeGetCurrent() + RunTime(maxTime);

		while ([task isRunning])
		{
			if (CFAbsoluteTimeGetCurrent() > endTime)
			{
				[task terminate];
				dprintf("TIMED-OUT: `svn %@` after %g secs", args, RunTime(maxTime));
				break;
			}
			[outData appendData: [outf availableData]];
			[errData appendData: [errf availableData]];
		//	dprintf("outData=%@\n    errData=%@", outData, errData);
		}
		[outData appendData: [outf readDataToEndOfFile]];
		[errData appendData: [errf readDataToEndOfFile]];
		status = [task terminationStatus];
		if (qDebug && 0)
			dprintf_("    status=%d stderr=\"%@\" stdout=\"%@\"", status,
					 NewString_(errData), NewString_(outData));
	}
	@catch (id ex)
	{
		dprintf("CAUGHT EXCEPTION: %@", ex);
	}

	return status;
}


//----------------------------------------------------------------------------------------
// End of SvnInterface.m
