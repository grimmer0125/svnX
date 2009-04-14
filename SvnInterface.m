//----------------------------------------------------------------------------------------
//	SvnInterface.m - Interface to Subversion libraries
//
//	Copyright © Chris, 2003 - 2008.  All rights reserved.
//----------------------------------------------------------------------------------------

#include "SvnInterface.h"
#include "svn_config.h"
#include "svn_fs.h"
#include "svn_auth.h"
#include "NSString+MyAdditions.h"


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
#ifndef SVN_LIBS
	#define	SVN_LIBS	/opt/subversion/lib
#endif
#define	STR_STR(s)			#s
#define	APR_LIB_PATH(dir)	(@"" STR_STR(dir) "/libapr-1.0.dylib")
	NSString* const apr_lib_path = APR_LIB_PATH(SVN_LIBS);
#undef	APR_LIB_PATH
#undef	STR_STR
	static BOOL inited = FALSE, exists = FALSE;

	if (!inited)
	{
		inited = TRUE;
		const intptr_t fn1 = (intptr_t) svn_fs_initialize,
					   fn2 = (intptr_t) apr_initialize,
					   fn3 = (intptr_t) svn_ver_check_list;

	#if qDebug
		if (![[NSFileManager defaultManager] fileExistsAtPath: apr_lib_path])
			dprintf("missing lib '%s'", [apr_lib_path UTF8String]);
	#endif
		// Initialize the APR & SVN libraries.
		if (fn1 != 0 && fn2 != 0 && fn3 != 0 &&
			[[NSFileManager defaultManager] fileExistsAtPath: apr_lib_path])
		{
		#if 0
			setenv("LC_ALL", "en_GB.UTF-8", 1);
			exists = (svn_cmdline_init(kAppName, qDebug ? stderr : NULL) == EXIT_SUCCESS);
		#elif 1
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
						{ NULL, NULL }
					};

					SVN_VERSION_DEFINE(my_version);

					SvnError err = svn_ver_check_list(&my_version, checklist);
					exists = (err == NULL);
				#if qDebug
					if (err)
						DbgSvnPrint(err);
				#endif
				}
				else
					dprintf("lapr_initialize() != APR_SUCCESS", 0);
			}
		#endif
		}
		if (!exists)
			dprintf("svn_fs_initialize=0x%X apr_initialize=0x%X", fn1, fn2);
	}

	return exists;
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
//	const id delegate = (id) baton;
	NSMutableString* msg = [NSMutableString string];
	if (failures & SVN_AUTH_SSL_UNKNOWNCA)
		[msg appendString: UTF8("\xE2\x80\xA2 The certificate is not issued by a trusted authority.\n"
								"   Use the fingerprint to validate the certificate manually!\n")];

	if (failures & SVN_AUTH_SSL_CNMISMATCH)
	{
		[msg appendString: UTF8("\xE2\x80\xA2 The certificate hostname does not match.\n")];
	} 

	if (failures & SVN_AUTH_SSL_NOTYETVALID)
	{
		[msg appendString: UTF8("\xE2\x80\xA2 The certificate is not yet valid.\n")];
	}

	if (failures & SVN_AUTH_SSL_EXPIRED)
	{
		[msg appendString: UTF8("\xE2\x80\xA2 The certificate has expired.\n")];
	}

	if (failures & SVN_AUTH_SSL_OTHER)
	{
		[msg appendString: UTF8("\xE2\x80\xA2 The certificate has an unknown error.\n")];
	}

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
// End of SvnInterface.m
