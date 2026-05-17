#ifndef _APP_VERSION_H_
#define _APP_VERSION_H_

/*  values come from cmake/version.cmake
 * BUILD_VERSION related  values will be 'git describe',
 * alternatively user defined BUILD_VERSION.
 */

/* #undef ZEPHYR_VERSION_CODE */
/* #undef ZEPHYR_VERSION */

#define APPVERSION          0x20100
#define APP_VERSION_NUMBER  0x201
#define APP_VERSION_MAJOR   0
#define APP_VERSION_MINOR   2
#define APP_PATCHLEVEL      1
#define APP_VERSION_STRING  "0.2.1"

#define APP_BUILD_VERSION v0.2


#endif /* _APP_VERSION_H_ */
