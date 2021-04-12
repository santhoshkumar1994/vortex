#pragma once

#include "types.h"
#include <unordered_map>
#include <unordered_set>
#include <vector>

using namespace std;

namespace vortex {
    class FOATableEntry {
        public:
            Word PC;
            Word address;
            int offset;
            int confidence;
            int tid;
    };

    class IPrefetcher {
        public:
            virtual void processLoadRequest(Word PC, Word address, int tid) = 0;
            virtual void sendPrefetchRequests(int numActiveThreadsInCurrentWarp, int numActiveWarps) = 0;
            virtual bool isAddressPrefetched(Word address) = 0;
    };

    class NextLinePrefetcher : public IPrefetcher {
        public:
        unordered_set<Word> prefetchCache;

        void processLoadRequest(Word PC, Word address, int tid) {
            prefetchCache.insert((address + 64) / 64);
        }

        void sendPrefetchRequests(int numActiveThreadsInCurrentWarp, int numActiveWarps) {
            // NOOP
        }

        bool isAddressPrefetched(Word address) {
            if (prefetchCache.find(address / 64) != prefetchCache.end()) {
                return true;
            } else {
                return false;
            }
        }
    };

    class ApogeePrefetcher : public IPrefetcher {
        private:
            bool isEntryAvailableForPC(Word PC) {
                if (entryForPC.find(PC) == entryForPC.end()) {
                    return false;
                } else {
                    return true;
                }
            }

            void addEntryForPC(Word PC, Word address, int tid) {
                FOATableEntry *entry = new FOATableEntry();
                entry->PC = PC;
                entry->address = address;
                entry->tid = tid;
                entry->confidence = 0;
                entry->offset = 0;
            }

            void updateEntryForPC(Word PC, Word address, int tid) {
                FOATableEntry *entry = entryForPC.at(PC);
        
                int new_offset = (address - entry->address) / (tid - entry->tid);
                if (entry->confidence == 0) {
                    entry->offset = new_offset;
                    entry->confidence = 1;
                } else {
                    if (new_offset != entry->offset) {
                       // Maybe not a uniform access pattern
                        entry->confidence = 0;
                    } else {
                        entry->confidence++;
                    }
                }
            }

        public:
            unordered_map<Word, FOATableEntry*> entryForPC;
            unordered_set<Word> prefetchCache;

            void processLoadRequest(Word PC, Word address, int tid) {
                if (isEntryAvailableForPC(PC)) {
                    updateEntryForPC(PC, address, tid);
                } else {
                    addEntryForPC(PC, address, tid);
                }
            }

            void sendPrefetchRequests(int numActiveThreadsInCurrentWarp, int numActiveWarps) {
                vector<Word> processedEntries;
                for (auto& p: entryForPC) {
                    if (p.second->confidence > numActiveThreadsInCurrentWarp - 2) {
                        Word newAddress = p.second->address + p.second->offset * (numActiveThreadsInCurrentWarp * numActiveWarps);
                        Word newLineAddress = newAddress / 64;
                        prefetchCache.insert(newLineAddress); 
                        processedEntries.push_back(p.first);
                    }
                }

                if (processedEntries.size() != 0) {
                    for (Word pc : processedEntries) {
                        entryForPC.erase(pc);
                    }
                }
            }

            bool isAddressPrefetched(Word address) {
                if (prefetchCache.find(address / 64) != prefetchCache.end()) {
                    return true;
                } else {
                    return false;
                }
            }
    };
}