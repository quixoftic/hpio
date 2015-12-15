-- | A 'GpioF' interpreter for Linux GPIO via sysfs.

{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE OverloadedStrings #-}

module System.GPIO.Linux.Sysfs
       ( -- * MonadSysfs class
         MonadSysfs(..)
         -- * The Linux sysfs GPIO interpreter
       , SysfsF
       , SysfsT
       , runSysfsT
         -- * Linux sysfs GPIO types
       , PinDescriptor(..)
       ) where

import Control.Monad (void)
import Control.Monad.Except (MonadError, catchError, throwError)
import Control.Monad.Trans.Free (iterT)
import System.GPIO.Free (GpioF(..), GpioT, PinDirection(..), Pin(..), PinValue(..), openPin, closePin, readPin, writePin, getPinDirection, setPinDirection, invertDirection, invertValue)
import System.GPIO.Linux.MonadSysfs (MonadSysfs(..))

-- | The sysfs interpreter's pin handle type. Currently it's just a
-- newtype wrapper around a 'Pin'. The constructor is exported for
-- convenience, but note that the implementation may change in future
-- versions of the package.
newtype PinDescriptor = PinDescriptor { pin :: Pin } deriving (Show, Eq, Ord)

-- | A monad transformer which adds Linux sysfs GPIO computations to
-- other monads.
type SysfsT m = GpioT String PinDescriptor m

-- | The Linux sysfs GPIO DSL type.
type SysfsF m = GpioF String PinDescriptor m

-- | Run a 'SysfsT' computation embedded in monad 'm' and return the
-- result. Errors that occur in the computation or in the interpreter
-- are thrown with a 'String' argument via 'throwError', so the
-- wrapped monad must also be an instance of 'MonadError' 'String'.
-- Any 'Control.Exception.Base.IOException's that occur as a side
-- effect of the computation are not handled here and are simply
-- propagated upwards.
--
-- (Errors that could occur in the interpreter are generally limited
-- to reading unexpected results from various sysfs GPIO control
-- files.)
runSysfsT :: (MonadError String m, MonadSysfs m) => (SysfsT m) m a -> m a
runSysfsT = iterT run
  where
    run :: (MonadError String m, MonadSysfs m) => (SysfsF m) (m a) -> m a

    run (Pins next) =
      do hasSysfs <- sysfsIsPresent
         case hasSysfs of
           False -> next []
           True -> availablePins >>= next

    -- Export the pin. Note that it may already be exported, which we
    -- treat as success.
    run (OpenPin p next) =
      do hasSysfs <- sysfsIsPresent
         case hasSysfs of
           False -> next (Left "sysfs GPIO is not present")
           True ->
             do exported <- pinIsExported p
                case exported of
                  True -> next (Right $ PinDescriptor p)
                  False ->
                    do exportPin p
                       next (Right $ PinDescriptor p)

    run (OpenPinWithValue p v next) =
      do eitherHandle <- runSysfsT $ openPin p
         case eitherHandle of
           Left e -> next $ Left e
           Right h ->
             do settable <- pinHasDirection p
                case settable of
                  False ->
                    do runSysfsT $ closePin h
                       next (Left $ "Can't configure " ++ show p ++ " for output")
                  True ->
                    do writePinDirectionWithValue p v
                       next $ Right h

    run (ClosePin d next) =
      do let p = pin d
         unexportPin p
         next

    run (GetPinDirection d next) =
      do let p = pin d
         settable <- pinHasDirection p
         case settable of
           False -> next Nothing
           True ->
             do dir <- readPinDirection p
                case dir of
                  "in\n"  -> next $ Just In
                  "out\n" -> next $ Just Out
                  _     -> throwError $ "Unexpected direction value for " ++ show p

    run (SetPinDirection d dir next) =
      do let p = pin d
         writePinDirection p dir
         next

    run (TogglePinDirection d next) =
      do maybeDir <- runSysfsT $ getPinDirection d
         case maybeDir of
           Nothing -> next Nothing
           Just dir ->
             do let newDir = invertDirection dir
                void $ runSysfsT $ setPinDirection d newDir
                next $ Just newDir

    run (ReadPin d next) =
      do let p = pin d
         value <- readPinValue p
         case value of
           "0\n" -> next Low
           "1\n" -> next High
           _   -> throwError $ "Unexpected pin value for " ++ show p

    run (WritePin d v next) =
      do let p = pin d
         writePinValue p v
         next

    run (TogglePinValue h next) =
      do val <- runSysfsT $ readPin h
         let newVal = invertValue val
         void $ runSysfsT $ writePin h newVal
         next newVal

    run (WithPin p block next) =
      do result <- runSysfsT $ openPin p
         case result of
           Left e -> throwError e
           Right pd ->
             catchError
               (do a <- runSysfsT $ block pd
                   runSysfsT $ closePin pd
                   next a)
               (\e ->
                 do runSysfsT $ closePin pd
                    throwError e)
