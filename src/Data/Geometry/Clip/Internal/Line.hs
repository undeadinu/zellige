{-# LANGUAGE FlexibleContexts #-}

-- Cohen Sutherland Line Clipping Algorithm
module Data.Geometry.Clip.Internal.Line where

import qualified Data.Foldable                 as Foldable
import qualified Data.Geospatial               as Geospatial
import qualified Data.LineString               as LineString
import qualified Data.Sequence                 as Sequence

import qualified Data.Geometry.Types.Geography as TypesGeography

getLines :: Geospatial.GeoLine -> Sequence.Seq TypesGeography.GeoStorableLine
getLines (Geospatial.GeoLine line) = linesFromPoints line
{-# INLINE getLines #-}

linesFromPoints :: LineString.LineString Geospatial.GeoPositionWithoutCRS -> Sequence.Seq TypesGeography.GeoStorableLine
linesFromPoints = LineString.combineToSeq (\x y -> TypesGeography.GeoStorableLine (Geospatial.retrieveXY x) (Geospatial.retrieveXY y))
{-# INLINE linesFromPoints #-}

pointsFromLine :: TypesGeography.GeoStorableLine -> Sequence.Seq Geospatial.PointXY
pointsFromLine (TypesGeography.GeoStorableLine p1 p2) = Sequence.fromList [p1, p2]
{-# INLINE pointsFromLine #-}

-- Remove duplicate points in segments [(1,2),(2,3)] becomes [1,2,3]
segmentToLine :: Sequence.Seq a  -> Sequence.Seq a
segmentToLine l = if Sequence.length l > 1 then start Sequence.<| second l else mempty
  where
    start = Sequence.index l 0
    second = Sequence.foldrWithIndex (\i newElem acc -> if odd i then newElem Sequence.<| acc else acc) Sequence.empty
{-# INLINE segmentToLine #-}

-- Fold points from line to a vector of points
lineToGeoPoint :: Sequence.Seq TypesGeography.GeoStorableLine -> Sequence.Seq Geospatial.GeoPositionWithoutCRS
lineToGeoPoint = segmentToLine . Foldable.foldr (mappend . (\(TypesGeography.GeoStorableLine p1 p2) -> Sequence.fromList [Geospatial.GeoPointXY p1, Geospatial.GeoPointXY p2])) mempty
{-# INLINE lineToGeoPoint #-}

lineToPointXY :: Sequence.Seq TypesGeography.GeoStorableLine -> Sequence.Seq Geospatial.PointXY
lineToPointXY = Foldable.foldr (mappend . (\(TypesGeography.GeoStorableLine p1 p2) -> Sequence.fromList [p1, p2])) mempty
{-# INLINE lineToPointXY #-}
