#if defined JB_JAILBREAK_INC
 #endinput
#endif
#define JB_JAILBREAK_INC

native bool IsRebel(int client);
native void RefreshName(int client, int team);
native void GetRules(int client, char[] rules, int maxLength);
native void GetOriginalName(int client, char[] name, int length);
