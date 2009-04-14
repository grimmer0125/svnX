//----------------------------------------------------------------------------------------
//	SvnInterface.h - Interface to Subversion libraries
//
//	Copyright © Chris, 2003 - 2008.  All rights reserved.
//----------------------------------------------------------------------------------------

#pragma once

#include "DbgUtils.h"

#ifndef DARWIN
#define	DARWIN
#endif
#include "svn_client.h"
#include "svn_cmdline.h"
#include "svn_pools.h"


//----------------------------------------------------------------------------------------

typedef enum svn_wc_status_kind		SvnWCStatusKind;
typedef apr_pool_t*					SvnPool;
typedef apr_array_header_t*			SvnArray;
typedef svn_boolean_t				SvnBool;
typedef svn_opt_revision_t			SvnOptRevision;
typedef svn_revnum_t				SvnRevNum;
typedef svn_error_t*				SvnError;
typedef svn_client_ctx_t*			SvnClient;
typedef svn_auth_baton_t*			SvnAuth;
typedef svn_auth_provider_object_t* SvnAuthProvider;
typedef svn_wc_status2_t*			SvnStatus;
typedef const svn_info_t*			SvnInfo;
typedef struct SvnEnv				SvnEnv;

static const int kSvnRetryLimit = 2;
static const SvnBool kSvnRecurse = true;


//----------------------------------------------------------------------------------------

@protocol SvnInterface

	- (NSString*) user;
	- (NSString*) pass;

@end	// SvnInterface

//typedef NSObject<SvnInterface> SvnInterface;
typedef NSObject SvnInterface;


//----------------------------------------------------------------------------------------
// NSObject wrapper for svn_error_t*

@interface SvnException : NSObject
{
	SvnError	fError;
};

- (id) init: (SvnError) err;
- (SvnError) error;
- (NSString*) message;

@end	// SvnException


void SvnDoThrow		(SvnError err);
void SvnDoReport	(SvnError err);

#if qDebug
	#define SvnThrowIf(expr)				DbgSvnThrowIf((expr), _F_L_F_)
	#define SvnReportCatch(ex)				DbgSvnReportCatch((ex), _F_L_F_)

	void		DbgSvnPrint		(SvnError err);
	void		DbgSvnThrowIf	(SvnError err, ConstCStr file, int line, ConstCStr func);
	void		DbgSvnReportCatch(SvnException* ex, ConstCStr file, int line, ConstCStr func);
#elif !qDebug
	#define SvnThrowIf(expr)				SvnDoThrowIf((expr))
	#define SvnReportCatch(ex)				SvnDoReport([(ex) error])

	static inline void SvnDoThrowIf	(SvnError err)	{ if (err) SvnDoThrow(err); }
#endif


//----------------------------------------------------------------------------------------

BOOL		SvnInitialize		();
SvnPool		SvnNewPool			();
void		SvnDeletePool		(SvnPool pool);
NSString*	SvnRevNumToString	(SvnRevNum rev);
NSString*	SvnStatusToString	(SvnWCStatusKind kind);
SvnClient	SvnSetupClient		(SvnEnv** envRef, SvnInterface* delegate);
void		SvnEndClient		(SvnEnv* env);

static inline
SvnArray	SvnNewArray			(SvnPool pool, int count, int elem_size)
									{ return apr_array_make(pool, count, elem_size); }


//----------------------------------------------------------------------------------------
// End of SvnInterface.h
