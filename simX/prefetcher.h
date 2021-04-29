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
            virtual void processLoadRequest(Word PC, Word address, int tid, uint64_t step) = 0;
            virtual void sendPrefetchRequests(int numActiveThreadsInCurrentWarp, int numActiveWarps, uint64_t step) = 0;
            virtual bool isAddressPrefetched(Word address, uint64_t step) = 0;
            virtual void reset() = 0;
            virtual double getMeanTimeBetweenPrefetchAndAccess() = 0;
            virtual double getPercentageUsefulPrefetches() = 0;
    };

    class NoPrefetcher : public IPrefetcher {
        public:
        void processLoadRequest(Word PC, Word address, int tid, uint64_t step) {
            // NOOP
        }

        void sendPrefetchRequests(int numActiveThreadsInCurrentWarp, int numActiveWarps, uint64_t step) {
            // NOOP
        }

        void reset() {
            // NOOP
        }

        bool isAddressPrefetched(Word address, uint64_t step) {
            return false;
        }

        double getMeanTimeBetweenPrefetchAndAccess() {
            return 0.0;
        }

        double getPercentageUsefulPrefetches() {
            return 0.0;
        }
    };

    class NextLinePrefetcher : public IPrefetcher {
        public:
        unordered_set<Word> prefetchCache;
        unordered_map<Word, uint64_t> prefetchStepForAddress;
        int numSuccessfulPrefetches;
        int totalTimeBetweenPrefetchAndAccess;
        int prefetchesSent;

        NextLinePrefetcher() {
            numSuccessfulPrefetches = 0;
            totalTimeBetweenPrefetchAndAccess = 0;
            prefetchesSent = 0;
        }

        void processLoadRequest(Word PC, Word address, int tid, uint64_t step) {
            if (prefetchCache.find((address + 64) / 64) == prefetchCache.end()) {
                prefetchCache.insert((address + 64) / 64);
                prefetchStepForAddress.insert({(address + 64) / 64, step});
            }

            prefetchesSent++;
        }

        void sendPrefetchRequests(int numActiveThreadsInCurrentWarp, int numActiveWarps, uint64_t step) {
            // NOOP
        }

        bool isAddressPrefetched(Word address, uint64_t step) {
            if (prefetchCache.find(address / 64) != prefetchCache.end()) {
                numSuccessfulPrefetches++;
                totalTimeBetweenPrefetchAndAccess += (step - prefetchStepForAddress.at(address / 64));
                return true;
            } else {
                return false;
            }
        }

        void reset() {
            prefetchCache.clear();
        }

        double getMeanTimeBetweenPrefetchAndAccess() {
            return ((double)totalTimeBetweenPrefetchAndAccess) / numSuccessfulPrefetches;
        }

        double getPercentageUsefulPrefetches() {
            return ((double) (numSuccessfulPrefetches)) / prefetchesSent;
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
                entryForPC.insert({PC, entry});
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
            unordered_map<Word, uint64_t> prefetchStepForAddress;
            int numSuccessfulPrefetches;
            int totalTimeBetweenPrefetchAndAccess;
            int prefetchesSent;

            ApogeePrefetcher() {
                numSuccessfulPrefetches = 0;
                totalTimeBetweenPrefetchAndAccess = 0;
                prefetchesSent = 0;
            }

            void processLoadRequest(Word PC, Word address, int tid, uint64_t step) {
                if (isEntryAvailableForPC(PC)) {
                    updateEntryForPC(PC, address, tid);
                } else {
                    addEntryForPC(PC, address, tid);
                }
            }

            void sendPrefetchRequests(int numActiveThreadsInCurrentWarp, int numActiveWarps, uint64_t step) {
                vector<Word> processedEntries;
                for (auto& p: entryForPC) {
                    if (p.second->confidence > numActiveThreadsInCurrentWarp - 2) {                        
                        Word newAddress = p.second->address + p.second->offset * (numActiveThreadsInCurrentWarp * numActiveWarps);
                        Word newLineAddress = newAddress / 64;
                        prefetchCache.insert(newLineAddress);
                        prefetchStepForAddress.insert({newLineAddress, step});
                        processedEntries.push_back(p.first);
                        prefetchesSent++;
                    }
                }

                if (processedEntries.size() != 0) {
                    for (Word pc : processedEntries) {
                        entryForPC.erase(pc);
                    }
                }
            }

            bool isAddressPrefetched(Word address, uint64_t step) {
                if (prefetchCache.find(address / 64) != prefetchCache.end()) {
                    numSuccessfulPrefetches++;
                    totalTimeBetweenPrefetchAndAccess += (step - prefetchStepForAddress.at(address / 64));
                    return true;
                } else {
                    return false;
                }
            }

            void reset() {
                entryForPC.clear();
                prefetchCache.clear();
            }

            double getMeanTimeBetweenPrefetchAndAccess() {
                return ((double)totalTimeBetweenPrefetchAndAccess) / numSuccessfulPrefetches;
            }

            double getPercentageUsefulPrefetches() {
                return ((double) (numSuccessfulPrefetches)) / prefetchesSent;
            }
    };
}