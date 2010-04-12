/*
 * apr_svn.c - apr & svn .dylib stubs for functions used by svnX
 */

#define	FN(fn)	extern void fn (void); void fn (void) {}

/*----------------------------------------------------------------------*/

#ifdef LIB_svn_client

	FN(svn_client_info)
	FN(svn_client_list)
	FN(svn_client_log3)
	FN(svn_client_status2)
	FN(svn_client_create_context)
	FN(svn_client_proplist2)
	FN(svn_client_propset2)
	FN(svn_client_version)

#endif	// LIB_svn_client


/*----------------------------------------------------------------------*/

#ifdef LIB_svn_subr

	FN(svn_pool_create_ex)
	FN(svn_config_ensure)
	FN(svn_config_get_config)
	FN(svn_handle_error2)
	FN(svn_error__locate)
	FN(svn_error_create)
	FN(svn_error_clear)
	FN(svn_auth_get_keychain_simple_provider)
	FN(svn_auth_get_simple_provider)
	FN(svn_auth_get_username_provider)
	FN(svn_auth_get_ssl_client_cert_file_provider)
	FN(svn_auth_get_ssl_client_cert_pw_file_provider)
	FN(svn_auth_get_ssl_server_trust_file_provider)
	FN(svn_auth_get_ssl_server_trust_prompt_provider)
	FN(svn_auth_open)
	FN(svn_auth_set_parameter)
	FN(svn_subr_version)
	FN(svn_ver_check_list)
	FN(svn_base64_decode_string)
	FN(svn_string_create)
	FN(svn_string_ncreate)

#endif	// LIB_svn_subr


/*----------------------------------------------------------------------*/

#ifdef LIB_svn_fs

	FN(svn_fs_initialize)
	FN(svn_fs_version)

#endif	// LIB_svn_fs


/*----------------------------------------------------------------------*/

#ifdef LIB_svn_wc

	FN(svn_wc_version)

#endif	// LIB_svn_wc


/*----------------------------------------------------------------------*/

#ifdef LIB_apr

	FN(apr_initialize)
	FN(apr_palloc)
	FN(apr_pstrdup)
	FN(apr_pool_destroy)
	FN(apr_array_make)
	FN(apr_array_push)
	FN(apr_hash_count)
	FN(apr_hash_first)
	FN(apr_hash_next)
	FN(apr_hash_this)

#endif	// LIB_apr


/*
----------------------------------------------------------------------
LIBS="svn_client svn_subr svn_fs apr"
OTHER_LDFLAGS = -weak_library $APR_SVN/libsvn_client.dylib \
				-weak_library $APR_SVN/libsvn_subr.dylib \
				-weak_library $APR_SVN/libsvn_fs.dylib \
				-weak_library $APR_SVN/libsvn_wc.dylib \
				-weak_library $APR_SVN/libapr.dylib
SVN_LIBS = /opt/subversion/lib
----------------------------------------------------------------------
*/

