#if defined JB_JAILBREAK_INC
 #endinput
#endif
#define JB_JAILBREAK_INC

native bool IsRebel(int client);
native void GetRules(int client, char[] rules, int maxLength);
